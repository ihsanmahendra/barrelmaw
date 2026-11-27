extends SceneTree
## Headless checks and a balance bot. Run:
## godot --headless --path prototype --script res://tests/run_tests.gd

var failures: int = 0


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("FAIL: ", msg)


func _init() -> void:
	GameData.ensure_loaded()
	test_art_import()
	test_data()
	test_cards()
	test_tutorial_script()
	test_preview_matches_play()
	test_unlocks()
	test_specials()
	test_menu_data()
	test_save_data()
	var packs := PackTests.new()
	packs.run()
	failures += packs.failures
	bot_report(60)
	print("Failures: ", failures)
	quit(1 if failures > 0 else 0)


## Barrels are drawn much smaller than their pictures, so they need mipmaps or they shimmer.
func test_art_import() -> void:
	for n in ["barrel", "barrel_atlas"]:
		var tex: Texture2D = load("res://assets/art/%s.png" % n)
		check(tex.get_image().has_mipmaps(), n + ".png imported with mipmaps")


func test_data() -> void:
	check(GameData.cards.size() >= 30 and GameData.cards.size() <= 40, "card count in 30-40, got %d" % GameData.cards.size())
	check(GameData.pictures.size() == Stages.TOTAL, "20 pictures, one per stage")
	for id in GameData.starter_deck:
		check(GameData.cards.has(id), "starter card exists: " + str(id))
	for pic in GameData.pictures:
		var w: int = String(pic["rows"][0]).length()
		var colors := {}
		for r in pic["rows"]:
			check(String(r).length() == w, "%s row width" % pic["name"])
			for ch in String(r):
				if ch != ".":
					colors[ch] = true
					check(GameData.palette.has(ch), "%s palette %s" % [pic["name"], ch])
		check(colors.size() <= 5, "%s has <= 5 colors" % pic["name"])


func test_cards() -> void:
	var rows := ["RRR", "RBR", "RRR"]
	var b := Battle.new(rows, ["row_strike"], 1.5, 1, 1)
	check(b.board.count() == 9, "board count")
	b.queue = [{"color": "R", "ammo": 1}, {"color": "B", "ammo": 1}]
	check(b.play_card(0), "play card")
	b.fire()
	check(b.board.get_c(0, 2) == "" and b.board.get_c(1, 2) == "" and b.board.get_c(2, 2) == "", "row cleared")
	check(b.board.count() == 6, "exactly one row removed, got %d" % b.board.count())
	var b2 := Battle.new(["RB", "BR"], ["wildcard"], 1.5, 1, 2)
	b2.queue = [{"color": "R", "ammo": 2}]
	b2.play_card(0)
	b2.fire()
	check(b2.board.count() == 2, "wild hit 2 cells of any color, left %d" % b2.board.count())
	var b3 := Battle.new(["R", "R", "R"], ["skip"], 1.0, 1, 3)
	b3.queue = [{"color": "R", "ammo": 1}]
	b3.fire()
	check(b3.over and not b3.won, "queue empty is a loss")
	var b4 := Battle.new(["R"], ["skip"], 1.0, 1, 4)
	b4.queue = [{"color": "R", "ammo": 1}]
	b4.fire()
	check(b4.over and b4.won, "cleared board is a win")
	for id in GameData.card_order:
		var bb := Battle.new(GameData.pictures[3]["rows"], [id, id, id], 1.5, 3, 7)
		bb.play_card(0)
		bb.fire()
		check(bb.turns >= 1, "card played " + id)


## Previewing a card on a clone must match really playing it, including random cards.
func test_preview_matches_play() -> void:
	for id in GameData.card_order:
		for seed_value in [11, 12, 13]:
			var b := Battle.new(GameData.pictures[seed_value % 10]["rows"], [id, id, id], 0.8, 3, seed_value, {}, {"bomb": 2, "ammo": 1, "iron": 3, "curse": 2})
			var pv := b.preview_card(0)
			var after: Battle = pv["battle"]
			b.play_card(0)
			check(after.board.cells == b.board.cells, "preview board matches for " + id)
			check(after.queue == b.queue, "preview queue matches for " + id)
			check(after.hand == b.hand, "preview hand matches for " + id)
			check(after.mods == b.mods, "preview mods match for " + id)


## The guided practice must always be winnable by following its steps.
func test_tutorial_script() -> void:
	var main_script: Script = load("res://scripts/ui/main.gd")
	var rows: Array = main_script.get("TUTORIAL_ROWS")
	var queue: Array = main_script.get("TUTORIAL_QUEUE")
	var hands: Array = main_script.get("TUTORIAL_HANDS")
	var b := Battle.new(rows, GameData.starter_deck, 1.0, 3, 1, {"queue": queue, "hands": hands})
	check(b.hand == ["power_shot", "skip", "wildcard"], "tutorial hand 1")
	b.play_card(0)  # Power Shot
	check(b.preview_targets().size() == 6, "power shot preview is 6, got %d" % b.preview_targets().size())
	b.fire()
	check(b.board.count() == 14 - 2 + 0 or b.board.count() == 14, "tutorial board after fire: %d" % b.board.count())
	check(b.hand[0] == "row_strike", "tutorial hand 2")
	b.play_card(0)  # Row Strike
	b.fire()
	check(not b.over or b.won, "tutorial not lost after row strike")
	var guard := 0
	while not b.over and guard < 10:
		guard += 1
		if b.hand.size() > 0:
			b.play_card(0)
		b.fire()
	check(b.over and b.won, "tutorial is winnable by following the script")


## Simple bot: scores each card by rough power, fires with the best one.
func bot_pick(b: Battle) -> int:
	return Bot.pick(b)


## Every card is available exactly once through the starter deck or an unlock, and new cards come
## in groups of six every 10 stages.
## Special barrels: bomb blasts, iron needs two hits, crates add a cannonball, skulls weaken the next.
func test_specials() -> void:
	# Bomb: hitting it also clears the 3x3 area around it, whatever the color.
	var b := Battle.new(["RBR", "BRB", "RBR", "..R"], ["skip"], 1.0, 1, 1)
	b.board.set_special(1, 1, "bomb")
	b.queue = [{"color": "R", "ammo": 1}, {"color": "R", "ammo": 4}]
	b.mods["wild"] = false
	b._remove(Vector2i(1, 1))
	check(b.board.count() == 1, "bomb clears its 3x3 neighbors, left %d" % b.board.count())
	check(b.events_last.any(func(e: Dictionary) -> bool: return e["kind"] == "bomb"), "bomb event recorded")
	# Chain: a bomb inside another bomb's blast also explodes.
	var c := Battle.new(["RRRRR", "RRRRR", "RRRRR"], ["skip"], 1.0, 1, 2)
	c.board.set_special(1, 1, "bomb")
	c.board.set_special(2, 1, "bomb")
	c._remove(Vector2i(1, 1))
	check(c.board.count() == 3, "chained bombs clear columns 0-3, left %d" % c.board.count())
	# Iron: first hit only cracks it, second hit breaks it.
	var d := Battle.new(["RR"], ["skip"], 1.0, 1, 3)
	d.board.set_special(0, 0, "iron")
	d._remove(Vector2i(0, 0))
	check(d.board.get_c(0, 0) == "R" and d.board.get_hp(0, 0) == 1 and d.damaged_last.size() == 1, "iron survives the first hit")
	d._remove(Vector2i(0, 0))
	check(d.board.get_c(0, 0) == "", "iron breaks on the second hit")
	# Supply crate: a free 3-hit cannonball goes to the front of the queue.
	var e := Battle.new(["RB"], ["skip"], 1.0, 1, 4)
	e.board.set_special(0, 0, "ammo")
	e.queue = [{"color": "B", "ammo": 2}]
	e._remove(Vector2i(0, 0))
	check(e.queue.size() == 2 and int(e.queue[0]["ammo"]) == Battle.AMMO_CRATE_HITS, "supply crate adds a cannonball")
	# Cursed skull: the next cannonball loses hits, but never below 1.
	var f := Battle.new(["RB"], ["skip"], 1.0, 1, 5)
	f.board.set_special(0, 0, "curse")
	f.queue = [{"color": "B", "ammo": 5}]
	f._remove(Vector2i(0, 0))
	check(int(f.queue[0]["ammo"]) == 5 - Battle.CURSE_HITS, "skull takes hits off the next cannonball")
	f.board.set_special(1, 0, "curse")
	f.queue[0]["ammo"] = 1
	f._remove(Vector2i(1, 0))
	check(int(f.queue[0]["ammo"]) == 1, "skull never takes the last hit")
	# Preview leaves the battle untouched, even with bombs and crates in play.
	var g := Battle.new(["RRRR", "RRRR", "RRRR"], ["skip"], 1.0, 1, 6)
	g.board.set_special(1, 2, "bomb")
	g.board.set_special(2, 2, "ammo")
	g.queue = [{"color": "R", "ammo": 3}, {"color": "R", "ammo": 2}]
	var before_cells: Array = g.board.cells.duplicate()
	var before_special: Array = g.board.special.duplicate()
	var before_queue: Array = g.queue.duplicate(true)
	var shown := g.preview_targets()
	check(g.board.cells == before_cells and g.board.special == before_special and g.queue == before_queue, "preview restores board, specials and queue")
	check(shown.size() > 0, "preview lists targets")
	# Stage specials appear gradually.
	check(Stages.specials_for(0).is_empty() and Stages.specials_for(1).is_empty(), "no specials on stages 1-2")
	check(Stages.specials_for(2).has("bomb") and not Stages.specials_for(2).has("iron"), "bombs from stage 3")
	check(Stages.specials_for(11).has("curse") and Stages.specials_for(11).has("iron"), "skulls by stage 12")
	for i in Stages.TOTAL:
		var total := 0
		for k in Stages.specials_for(i):
			total += int(Stages.specials_for(i)[k])
		var cells := 0
		for r in Stages.picture(i)["rows"]:
			for ch in String(r):
				if ch != ".":
					cells += 1
		check(total <= cells / 4, "stage %d has too many specials (%d of %d cells)" % [i + 1, total, cells])


func test_unlocks() -> void:
	var seen := {}
	for id in GameData.starter_deck:
		seen[id] = true
	for k in Stages.UNLOCKS:
		check(int(k) % 10 == 0 and int(k) > 0, "unlock stage is a multiple of 10: %s" % str(k))
		check(Stages.UNLOCKS[k].size() == 6, "six cards per unlock")
		for id in Stages.UNLOCKS[k]:
			check(GameData.cards.has(id), "unlock card exists: " + str(id))
			check(not seen.has(id), "card unlocked only once: " + str(id))
			seen[id] = true
	var stage_cards := 0
	for id in GameData.card_order:
		if GameData.cards[id]["rarity"] == "transcended":
			check(not seen.has(id), "Transcended cards are chest-only, not unlocked by stages: " + str(id))
		else:
			stage_cards += 1
	check(seen.size() == stage_cards, "starter deck plus unlocks cover all %d stage cards, got %d" % [stage_cards, seen.size()])
	check(Stages.deck_for(0).size() == GameData.starter_deck.size(), "stage 1 uses the starter deck")
	check(Stages.deck_for(10).size() == GameData.starter_deck.size() + 6, "stage 11 adds six cards")
	check(Stages.deck_for(49).size() == GameData.starter_deck.size() + 24, "stage 50 has every card")


func test_menu_data() -> void:
	check(Stages.next_boss(0) == 9 and Stages.next_boss(9) == 9 and Stages.next_boss(10) == 19 and Stages.next_boss(49) == 49, "next boss stage")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var counts := {"rare": 0, "epic": 0, "legendary": 0}
	for i in 300:
		var id := Stages.roll_gift(rng)
		check(GameData.cards.has(id), "gift card exists")
		counts[GameData.cards[id]["rarity"]] += 1
	check(counts["rare"] > counts["epic"] and counts["epic"] > counts["legendary"], "gift rarity odds, got %s" % str(counts))
	SaveData.path = "user://test_save.cfg"
	SaveData.reset()
	check(SaveData.daily_available(), "gift available on a fresh save")
	SaveData.claim_daily("blast")
	check(not SaveData.daily_available() and SaveData.pending_gift() == "blast", "claiming records today and the card")
	check(SaveData.take_pending_gift() == "blast" and SaveData.pending_gift() == "" and SaveData.take_pending_gift() == "", "gift is used once")
	SaveData.reset()


func test_save_data() -> void:
	SaveData.path = "user://test_save.cfg"
	SaveData.reset()
	check(SaveData.highest_unlocked() == 0 and SaveData.is_unlocked(0) and not SaveData.is_unlocked(1), "only stage 1 unlocked at start")
	SaveData.set_debug_unlock(true)
	check(SaveData.is_unlocked(99) and SaveData.highest_unlocked() == 0, "debug mode opens every stage")
	SaveData.set_debug_unlock(false)
	check(not SaveData.is_unlocked(99), "debug mode off locks them again")
	SaveData.record(0, 2)
	check(SaveData.stars(0) == 2 and SaveData.is_unlocked(1) and not SaveData.is_unlocked(2), "clearing a stage unlocks the next")
	SaveData.record(0, 1)
	check(SaveData.stars(0) == 2, "best stars are kept")
	SaveData.record(1, 3)
	check(not SaveData.intro_seen(10), "intro not seen yet")
	SaveData.mark_intro_seen(10)
	check(SaveData.intro_seen(10), "intro remembered")
	check(SaveData.total_stars() == 5 and SaveData.cleared_count() == 2, "star totals")
	SaveData.reset()
	check(SaveData.total_stars() == 0, "reset clears progress")
	# Star ratings follow the turn limits.
	var b := Battle.new(["R"], ["skip"], 1.0, 1, 1)
	b.star3_turns = 5
	b.star2_turns = 8
	b.queue = [{"color": "R", "ammo": 3}]
	b.fire()
	check(b.won and b.turns <= 5 and b.star_rating() == 3, "finishing within the 3-star limit gives 3 stars")
	b.turns = 7
	check(b.star_rating() == 2, "within the 2-star limit gives 2 stars")
	b.turns = 12
	check(b.star_rating() == 1, "beyond the limits gives 1 star")
	check(b.star_limit() == -1, "no turn limit once only 1 star is left")


## Plays every stage many times with the bot (starter deck plus one random drafted card) and
## prints the win rate and average stars per stage. Use it to tune Stages.SLACK_*.
func bot_report(n: int) -> void:
	var total_wins := 0
	var total_games := 0
	for stage in Stages.TOTAL:
		var wins := 0
		var stars_sum := 0
		var attempts := 0
		for r in n:
			var rng := RandomNumberGenerator.new()
			rng.seed = 5000 + stage * 1000 + r
			var deck: Array = Stages.deck_for(stage)
			var b := Stages.new_battle(stage, deck, rng.randi())
			var guard := 0
			while not b.over and guard < 500:
				guard += 1
				var pick := bot_pick(b)
				if pick >= 0:
					b.play_card(pick)
				if not b.over:
					b.fire()
			attempts += 1
			if b.won:
				wins += 1
				stars_sum += b.star_rating()
		total_wins += wins
		total_games += attempts
		print("  stage %2d %-9s win %3.0f%%  avg stars %.2f" % [stage + 1, Stages.picture(stage)["name"], 100.0 * wins / attempts, float(stars_sum) / maxf(1.0, wins)])
	print("Bot overall win rate: %.0f%%" % (100.0 * total_wins / total_games))
