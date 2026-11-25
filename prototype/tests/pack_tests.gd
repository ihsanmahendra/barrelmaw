class_name PackTests
extends RefCounted
## Checks for card packs, merge, levels, rewards and the save. Called from run_tests.gd.
## Spec: design/gdd/card-packs.md, section 8 (acceptance criteria 1 to 5 and 8 to 9).

var failures: int = 0
const TEST_SAVE: String = "user://test_packs_save.cfg"


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("FAIL: ", msg)


func run() -> void:
	PackConfig.ensure_loaded()
	test_pack_data()
	test_odds()
	test_pity()
	test_no_impossible_pulls()
	test_merge_math()
	test_first_crate_and_open_rules()
	test_daily()
	test_stage_rewards()
	test_market()
	test_duplicate_protection()
	test_save_and_migration()
	test_level_data()
	test_level_effects()
	test_level_parity()
	test_transcended_cards()
	test_transcended_effects()
	test_echo_parity()
	test_captain_slots()


func _catalog() -> Dictionary:
	return GameData.cards.duplicate()


## The cards without any Transcended card (what the game had before phase 3).
func _catalog_without_top() -> Dictionary:
	var c := {}
	for id in GameData.cards:
		if GameData.cards[id]["rarity"] != "transcended":
			c[id] = GameData.cards[id]
	return c


## Deep equality that ignores key order.
func _same(a: Variant, b: Variant) -> bool:
	return JSON.stringify(a, "", true) == JSON.stringify(b, "", true)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


func test_pack_data() -> void:
	var prev_unlock := -1
	for c in PackConfig.chests:
		check(int(c["unlock_cleared"]) >= prev_unlock, "chests are ordered by unlock stage: " + str(c["id"]))
		prev_unlock = int(c["unlock_cleared"])
		var cards := 0
		for s in c["slots"]:
			var total := 0
			for r in s["odds"]:
				total += int(s["odds"][r])
				check(PackConfig.rank(str(r)) >= 0, "known rarity in odds: " + str(r))
			check(total == 100, "odds sum to 100 for %s, got %d" % [c["id"], total])
			cards += int(s["count"])
		check(cards == int(c["cards"]), "slot counts add up to cards for " + str(c["id"]))
	for r in PackConfig.data["rarities"]:
		check(PackConfig.data["merge_steps"][r].size() == PackConfig.max_level() - 1, "a merge step per level for " + str(r))
		check(PackConfig.pearls_for(str(r)) > 0, "pearl value for " + str(r))
	check(PackConfig.total_to_max("common") == 18 and PackConfig.total_to_max("transcended") == 12, "spare copies to max level match the design")
	check(PackConfig.step("rare", PackConfig.max_level()) == 0, "no step beyond max level")


## 8.1: observed rarity rates are within 1 point of the tables (pity off).
func test_odds() -> void:
	var catalog := _catalog()
	var st := Collection.new_state()
	var pools := Collection.pools(100, catalog, st)
	for chest_src in PackConfig.chests:
		var chest: Dictionary = chest_src.duplicate(true)
		chest["pity"] = []
		var rng := _rng(11)
		var n := 12000
		var seen := {}
		for i in n:
			for c in Packs.roll_chest(chest, st, 100, catalog, rng, pools):
				seen[c["rarity"]] = int(seen.get(c["rarity"], 0)) + 1
		var total := float(n * int(chest["cards"]))
		for r in PackConfig.data["rarities"]:
			var expected := 0.0
			for s in chest["slots"]:
				expected += float(s["odds"].get(r, 0)) * float(s["count"]) / 100.0
			expected /= float(chest["cards"])
			var got := float(seen.get(r, 0)) / total
			check(absf(got - expected) <= 0.01, "%s %s rate %.3f vs table %.3f" % [chest["id"], r, got, expected])


## 8.2: with pity on, the counters never run past their limits and the guarantees hold.
func test_pity() -> void:
	var catalog := _catalog()
	# The limits promised by the design (acceptance criterion 8.2). The data file may be stricter, never looser.
	var epic_limit := 30
	var leg_limit := 60
	var vault_limit := 6
	check(int(PackConfig.pity("epic")) <= epic_limit and int(PackConfig.pity("legendary")) <= leg_limit and int(PackConfig.pity("vault_dry")) <= vault_limit, "pity thresholds in packs.json are within the design limits")
	for id in ["iron", "coffer", "gilded", "vault"]:
		var chest := PackConfig.chest(id)
		var st := Collection.new_state()
		var pools := Collection.pools(100, catalog, st)
		var rng := _rng(5)
		var worst_epic := 0
		var worst_leg := 0
		var worst_dry := 0
		var cards_since_epic := 0
		var worst_gap := 0
		var cards_since_leg := 0
		var worst_leg_gap := 0
		var vaults_dry := 0
		var worst_vault_streak := 0
		for i in 4000:
			var got := Packs.roll_chest(chest, st, 100, catalog, rng, pools)
			var has_epic := false
			for c in got:
				if PackConfig.rank(str(c["rarity"])) >= PackConfig.rank("epic"):
					has_epic = true
			var has_leg := false
			var has_top := false
			for c in got:
				if PackConfig.rank(str(c["rarity"])) >= PackConfig.rank("legendary"):
					has_leg = true
				if c["rarity"] == "transcended":
					has_top = true
			cards_since_epic = 0 if has_epic else cards_since_epic + got.size()
			cards_since_leg = 0 if has_leg else cards_since_leg + got.size()
			vaults_dry = 0 if has_top else vaults_dry + 1
			worst_gap = maxi(worst_gap, cards_since_epic)
			worst_leg_gap = maxi(worst_leg_gap, cards_since_leg)
			worst_vault_streak = maxi(worst_vault_streak, vaults_dry)
			worst_epic = maxi(worst_epic, int(st["pity"]["since_epic"]))
			worst_leg = maxi(worst_leg, int(st["pity"]["since_legendary"]))
			worst_dry = maxi(worst_dry, int(st["pity"]["vault_dry"]))
		check(worst_epic < epic_limit, "%s: epic counter stays under %d, got %d" % [id, epic_limit, worst_epic])
		check(worst_gap < epic_limit + int(chest["cards"]), "%s: never %d cards without an Epic or better, worst %d" % [id, epic_limit, worst_gap])
		if (chest["pity"] as Array).has("legendary"):
			check(worst_leg < leg_limit, "%s: legendary counter stays under %d, got %d" % [id, leg_limit, worst_leg])
			check(worst_leg_gap < leg_limit + int(chest["cards"]), "%s: never %d cards without a Legendary or better, worst %d" % [id, leg_limit, worst_leg_gap])
		if (chest["pity"] as Array).has("transcended"):
			check(worst_dry < vault_limit, "%s: vault counter stays under %d, got %d" % [id, vault_limit, worst_dry])
			check(worst_vault_streak <= vault_limit, "%s: never more than %d vaults without a Transcended card, worst %d" % [id, vault_limit, worst_vault_streak])
	# Without any Transcended card to give, the vault counter must not build up.
	var st2 := Collection.new_state()
	var rng2 := _rng(9)
	for i in 20:
		Packs.roll_chest(PackConfig.chest("vault"), st2, 100, _catalog_without_top(), rng2)
	check(int(st2["pity"]["vault_dry"]) == 0, "vault pity waits until a Transcended card exists")


## 8.3 and 8.4: never a locked card, never an empty slot, even with the smallest pool.
func test_no_impossible_pulls() -> void:
	var catalog := _catalog()
	for progress in [0, 9, 10, 29, 30, 39, 40, 49, 50, 100]:
		var st := Collection.new_state()
		var allowed := {}
		for id in Collection.unlocked_ids(progress, catalog, st):
			allowed[id] = true
		var pools := Collection.pools(progress, catalog, st)
		var rng := _rng(progress + 1)
		for chest in PackConfig.chests:
			for i in 120:
				var got := Packs.roll_chest(chest, st, progress, catalog, rng, pools)
				check(got.size() == int(chest["cards"]), "full card count for %s at %d cleared" % [chest["id"], progress])
				for c in got:
					check(allowed.has(c["id"]), "%s at %d cleared gave a locked card %s" % [chest["id"], progress, c["id"]])
	var st3 := Collection.new_state()
	var got3 := Packs.roll_chest(PackConfig.chest("vault"), st3, 0, GameData.cards, _rng(1))
	for c in got3:
		check(c["rarity"] == "common", "a vault with only starter cards unlocked steps down to common")
	# Reveal order: lowest rarity first.
	var st4 := Collection.new_state()
	var got4 := Packs.roll_chest(PackConfig.chest("gilded"), st4, 100, _catalog(), _rng(2))
	for i in range(1, got4.size()):
		check(PackConfig.rank(got4[i]["rarity"]) >= PackConfig.rank(got4[i - 1]["rarity"]), "cards are revealed lowest rarity first")


## 8.5: the exact number of copies reaches level 5, one fewer stops at level 4, extras become Pearls.
func test_merge_math() -> void:
	var catalog := _catalog()
	var samples := {"common": "power_shot", "rare": "cross_strike", "epic": "blast", "legendary": "prism", "transcended": "maelstrom"}
	for rarity in samples:
		var id: String = samples[rarity]
		var need := PackConfig.total_to_max(rarity)
		for spares in [need - 1, need]:
			var st := Collection.new_state()
			if rarity == "transcended":
				Collection.add_copy(st, id, catalog)  # the first copy only owns it
			for i in spares:
				Collection.add_copy(st, id, catalog)
			Collection.merge_all(st, catalog)
			var want := PackConfig.max_level() if spares == need else PackConfig.max_level() - 1
			check(Collection.level_of(st, id) == want, "%s with %d spares reaches level %d, got %d" % [rarity, spares, want, Collection.level_of(st, id)])
		# Extras beyond the cost are worth Pearls, both at merge time and at pull time.
		var st2 := Collection.new_state()
		if rarity == "transcended":
			Collection.add_copy(st2, id, catalog)
		for i in need + 3:
			Collection.add_copy(st2, id, catalog)
		Collection.merge_all(st2, catalog)
		check(int(st2["pearls"]) == 3 * PackConfig.pearls_for(rarity), "%s leftover spares become Pearls, got %d" % [rarity, int(st2["pearls"])])
		var res := Collection.add_copy(st2, id, catalog)
		check(int(res["pearls"]) == PackConfig.pearls_for(rarity) and int(st2["pearls"]) == 4 * PackConfig.pearls_for(rarity), "%s copy at max level gives Pearls" % rarity)
		check(not Collection.merge(st2, id, catalog), "no merge at max level")
	var st3 := Collection.new_state()
	check(not Collection.merge(st3, "power_shot", catalog), "cannot merge without copies")
	Collection.add_copy(st3, "power_shot", catalog)
	check(not Collection.is_ready(st3, "power_shot", catalog), "one spare is not enough for level 2")
	Collection.add_copy(st3, "power_shot", catalog)
	check(Collection.is_ready(st3, "power_shot", catalog) and Collection.ready_count(st3, catalog) == 1, "two spares make a common ready")
	check(Collection.merge(st3, "power_shot", catalog) and Collection.level_of(st3, "power_shot") == 2 and Collection.spare_of(st3, "power_shot") == 0, "merge spends the spares")
	check(Collection.levels_for_battle(st3) == {"power_shot": 2}, "battle level table lists cards above level 1")


func test_first_crate_and_open_rules() -> void:
	var catalog := _catalog()
	var st := Collection.new_state()
	var starter: Array = GameData.starter_deck
	check(not bool(Packs.open_chest(st, "crate", 0, catalog, _rng(1), starter)["ok"]), "cannot open a chest you do not have")
	Packs.grant(st, "iron")
	check(Packs.open_chest(st, "iron", 5, catalog, _rng(1), starter)["reason"] == "locked", "Ironbound is locked before stage 10 is cleared")
	check(Packs.count(st, "iron") == 1, "a locked chest is not consumed")
	Packs.grant(st, "crate", 2)
	var first := Packs.open_chest(st, "crate", 0, catalog, _rng(1), starter)
	check(bool(first["ok"]) and first["cards"].size() == 3, "first crate opens")
	check(first["cards"][0]["id"] == "power_shot" and first["cards"][1]["id"] == "power_shot", "first crate holds two copies of the most common starter card")
	check(Collection.is_ready(st, "power_shot", catalog), "first crate makes a card ready to merge at once")
	var second := Packs.open_chest(st, "crate", 0, catalog, _rng(2), starter)
	check(bool(second["ok"]) and second["cards"].size() == 3 and bool(st["first_crate_done"]), "later crates are random")
	check(Packs.count(st, "crate") == 0 and (st["pending"] as Array).size() == 2, "chests are used up and reveals queued")
	check(Packs.take_pending(st)["chest"] == "crate" and (st["pending"] as Array).size() == 1 and not Packs.take_pending(st).is_empty() and Packs.take_pending(st).is_empty(), "pending reveals come out in order")
	# Buying.
	st["doubloons"] = 700
	check(Packs.buy(st, "iron", 10) and int(st["doubloons"]) == 100 and Packs.count(st, "iron") == 2, "buying spends Doubloons")
	check(not Packs.buy(st, "iron", 10) and not Packs.buy(st, "coffer", 10), "too expensive or locked chests cannot be bought")


func test_daily() -> void:
	var st := Collection.new_state()
	check(Rewards.daily_available(st, "2026-11-25"), "daily crate is available on the first day")
	check(Rewards.daily_claim(st, "2026-11-25") == "crate" and Packs.count(st, "crate") == 1, "claim gives a Driftwood Crate")
	check(Rewards.daily_claim(st, "2026-11-25") == "" and not Rewards.daily_available(st, "2026-11-25"), "only one per day")
	check(Rewards.daily_available(st, "2026-11-26"), "next day gives another")
	Rewards.daily_claim(st, "2026-11-26")
	# Skipped days stack up to the cap.
	check(Rewards.daily_available(st, "2026-12-10") and int(st["daily"]["stack"]) == 3, "skipped days stack up to 3")
	# Clock set backwards cannot claim again.
	var st2 := Collection.new_state()
	Rewards.daily_claim(st2, "2026-11-25")
	check(not Rewards.daily_available(st2, "2026-11-20"), "an earlier date gives nothing")
	check(not Rewards.daily_available(st2, "2026-11-25"), "and the real date is still used up")
	# Every 7th claim is an Ironbound Chest.
	var st3 := Collection.new_state()
	var kinds: Array = []
	for d in 7:
		kinds.append(Rewards.daily_claim(st3, "2026-11-%02d" % (10 + d)))
	check(kinds[6] == "iron" and kinds[0] == "crate" and Packs.count(st3, "iron") == 1, "7th claim is an Ironbound Chest, got %s" % str(kinds))
	check(Rewards.days_between("2026-11-25", "2026-12-01") == 6, "date difference across a month")


func test_stage_rewards() -> void:
	var st := Collection.new_state()
	var best: Array = []
	best.resize(100)
	best.fill(0)
	var r := Rewards.stage_clear(st, 0, 0, 3, best, "2026-11-25")
	check(int(r["doubloons"]) == 100 and int(st["doubloons"]) == 100 and (r["chests"] as Dictionary).is_empty(), "first clear with 3 stars pays 100")
	r = Rewards.stage_clear(st, 1, 0, 1, best, "2026-11-25")
	check(int(r["doubloons"]) == 60, "first clear with 1 star pays 60")
	r = Rewards.stage_clear(st, 1, 1, 3, best, "2026-11-25")
	check(int(r["doubloons"]) == 40, "improving by two stars pays 40")
	var paid := 0
	for i in 8:
		paid += int(Rewards.stage_clear(st, 1, 3, 3, best, "2026-11-25")["doubloons"])
	check(paid == 50, "five paid replays per day, got %d" % paid)
	check(int(Rewards.stage_clear(st, 1, 3, 3, best, "2026-11-26")["doubloons"]) == 10, "replays pay again the next day")
	r = Rewards.stage_clear(st, 4, 0, 2, best, "2026-11-25")
	check(r["chests"] == {"crate": 2} and Packs.count(st, "crate") == 2, "elite stage first clear gives 2 crates")
	r = Rewards.stage_clear(st, 4, 0, 2, best, "2026-11-25")
	check((r["chests"] as Dictionary).is_empty(), "the elite reward is paid once")
	r = Rewards.stage_clear(st, 9, 0, 3, best, "2026-11-25")
	check(r["chests"] == {"iron": 2}, "stage 10 boss gives 2 Ironbound Chests")
	r = Rewards.stage_clear(st, 99, 0, 3, best, "2026-11-25")
	check(r["chests"] == {"vault": 2}, "stage 100 boss gives 2 Abyssal Vaults")
	# Night milestone: ten stages ending at 55 all with 3 stars.
	var three: Array = []
	three.resize(100)
	three.fill(0)
	for i in range(45, 54):
		three[i] = 3
	r = Rewards.stage_clear(st, 53, 3, 3, three, "2026-11-25")
	check(not (r["chests"] as Dictionary).has("vault"), "no vault while one stage lacks 3 stars")
	three[54] = 3
	r = Rewards.stage_clear(st, 54, 0, 3, three, "2026-11-25")
	check(int(r["chests"].get("vault", 0)) == 1 and Packs.count(st, "vault") == 3, "ten 3-star stages ending at 55 give a vault (plus 2 from stage 100)")
	r = Rewards.stage_clear(st, 54, 3, 3, three, "2026-11-26")
	check(not (r["chests"] as Dictionary).has("vault"), "the milestone is paid once")


func test_market() -> void:
	var catalog := _catalog()
	var st := Collection.new_state()
	st["pearls"] = 100
	check(Rewards.market_price("common") == 8 and Rewards.market_price("transcended") == 800, "market prices are 8 times the Pearl value")
	check(not Rewards.market_buy(st, "prism", 10, catalog, "2026-11-25"), "a locked card cannot be bought")
	check(Rewards.market_buy(st, "power_shot", 0, catalog, "2026-11-25") and int(st["pearls"]) == 92 and Collection.spare_of(st, "power_shot") == 1, "buying adds a copy and spends Pearls")
	for i in 4:
		check(Rewards.market_buy(st, "power_shot", 0, catalog, "2026-11-25"), "purchase %d within the weekly limit" % (i + 2))
	check(not Rewards.market_buy(st, "power_shot", 0, catalog, "2026-11-25"), "sixth purchase in a week is refused")
	check(Rewards.market_buy(st, "power_shot", 0, catalog, "2026-12-03"), "the limit resets the next week")
	st["pearls"] = 5
	check(not Rewards.market_buy(st, "power_shot", 0, catalog, "2026-12-10"), "not enough Pearls")


## Duplicate protection: all four Transcended cards arrive in a reasonable number of vaults.
func test_duplicate_protection() -> void:
	var catalog := _catalog()
	var total := 0
	var worst := 0
	var runs := 60
	for seed_value in runs:
		var st := Collection.new_state()
		var pools := Collection.pools(100, catalog, st)
		var rng := _rng(seed_value + 100)
		var vaults := 0
		while (st["owned"] as Dictionary).size() < 4 and vaults < 100:
			Packs.roll_chest(PackConfig.chest("vault"), st, 100, catalog, rng, pools)
			vaults += 1
		total += vaults
		worst = maxi(worst, vaults)
	check(float(total) / runs <= 16.0 and worst <= 50, "all four Transcended cards: mean %.1f vaults, worst %d" % [float(total) / runs, worst])


## 8.8 and 8.9: the save round-trips, a pending reveal cannot be rerolled, old saves migrate once.
func test_save_and_migration() -> void:
	var abs_path := ProjectSettings.globalize_path(TEST_SAVE)
	SaveData.path = TEST_SAVE
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(abs_path)
	var catalog := _catalog()
	SaveData.reset()
	var st := SaveData.pack_state()
	check(Packs.count(st, "crate") == 0, "a brand new save has no welcome crates")
	Packs.grant(st, "crate", 2)
	st["doubloons"] = 321
	st["pearls"] = 17
	Collection.add_copy(st, "power_shot", catalog)
	Collection.add_copy(st, "power_shot", catalog)
	Collection.merge(st, "power_shot", catalog)
	Collection.add_copy(st, "ghost_compass", catalog)
	st["pity"]["since_epic"] = 12
	Rewards.daily_claim(st, "2026-11-25")
	var opened := Packs.open_chest(st, "crate", 0, catalog, _rng(3), GameData.starter_deck)
	SaveData.save()
	var before := st.duplicate(true)
	SaveData.reload_from_disk()
	var after := SaveData.pack_state()
	check(_same(after, before), "pack state survives a save and load")
	check(Packs.count(after, "crate") == 2 and Collection.level_of(after, "power_shot") == 2 and Collection.level_of(after, "ghost_compass") == 1, "copies, levels and chests are kept")
	check((after["pending"] as Array).size() == 1 and _same(after["pending"][0]["cards"], opened["cards"]), "the pending reveal is saved with the same cards")
	var again := Packs.open_chest(after, "crate", 0, catalog, _rng(99), GameData.starter_deck)
	check(bool(again["ok"]) and (after["pending"] as Array).size() == 2, "the next chest opens and queues its own reveal")
	# Old save without packs: existing players get 3 crates once.
	DirAccess.remove_absolute(abs_path)
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "tutorial_done", true)
	cfg.set_value("progress", "stars", {"0": 3, "1": 2})
	cfg.save(TEST_SAVE)
	SaveData.reload_from_disk()
	check(Packs.count(SaveData.pack_state(), "crate") == 3 and bool(SaveData.pack_state()["welcome_given"]), "an old save with progress gets 3 Welcome Aboard crates")
	check(SaveData.stars(0) == 3 and SaveData.cleared_count() == 2, "old progress is untouched by the migration")
	SaveData.reload_from_disk()
	check(Packs.count(SaveData.pack_state(), "crate") == 3, "the welcome gift is not given twice")
	# Old save with no progress at all: nothing to welcome back.
	DirAccess.remove_absolute(abs_path)
	var cfg2 := ConfigFile.new()
	cfg2.set_value("progress", "debug_unlock", false)
	cfg2.save(TEST_SAVE)
	SaveData.reload_from_disk()
	check(Packs.count(SaveData.pack_state(), "crate") == 0, "an empty old save gets no welcome gift")
	# Missing keys from an older pack state are filled in.
	var thin := {"version": 1, "chests": {"crate": 1}}
	Collection.normalize(thin)
	check(thin.has("pity") and thin["pity"].has("vault_dry") and thin["chests"]["crate"] == 1, "normalize fills missing keys and keeps data")
	SaveData.reset()
	DirAccess.remove_absolute(abs_path)


# ---------- card levels (phase 2) ----------

## 8.6: every card has bonuses for levels 2 to 5 and they stay inside the power budget.
func test_level_data() -> void:
	for id in GameData.card_order:
		var card: Dictionary = GameData.cards[id]
		var levels: Array = card.get("levels", [])
		check(levels.size() == PackConfig.max_level() - 1, "%s has a bonus for each of levels 2 to 5" % id)
		if levels.size() != PackConfig.max_level() - 1:
			continue
		var powers := CardLevels.level_powers(card)
		var total := 0.0
		for i in powers.size():
			var cap := CardLevels.MASTERY_CAP_PP if i == powers.size() - 1 else CardLevels.LEVEL_CAP_PP
			check(float(powers[i]) <= cap + 0.001, "%s level %d adds %.1f power, over the %.1f cap" % [id, i + 2, powers[i], cap])
			total += float(powers[i])
		var total_cap := maxf(CardLevels.TOTAL_CAP_PP, 0.4 * CardLevels.base_power(card))
		check(total <= total_cap + 0.001, "%s adds %.1f power in total, over the %.1f cap" % [id, total, total_cap])
		for i in range(0, 3):  # levels 2 to 4 may not draw cards
			for entry in levels[i]:
				check(str(entry.get("kind", "")) != "draw", "%s gains no card draw before level 5" % id)
		check(CardLevels.bonus_text(card, 1) == "" and CardLevels.bonus_text(card, 5) != "", "%s describes its level bonus" % id)
	var ps: Dictionary = GameData.cards["power_shot"]
	check(CardLevels.bonus_text(ps, 3) == "+1 hit" and CardLevels.bonus_text(ps, 5) == "+3 hits", "bonus text for Power Shot: %s / %s" % [CardLevels.bonus_text(ps, 3), CardLevels.bonus_text(ps, 5)])
	check(CardLevels.bonus_text(GameData.cards["quick_draw"], 5) == "+2 hits, +1 card", "bonus text counts cards")


func _level_battle(id: String, level: int, seed_value: int = 3) -> Battle:
	var rows: Array = []
	for i in 8:
		rows.append("RRRRBBBB")
	var deck: Array = []
	deck.resize(10)
	deck.fill(id)
	var b := Battle.new(rows, deck, 1.5, 3, seed_value)
	b.levels = {id: level}
	return b


func test_level_effects() -> void:
	for id in GameData.card_order:
		var card: Dictionary = GameData.cards[id]
		check(CardLevels.effects_for(card, 1) == card["effects"], "level 1 keeps the base effects for " + id)
		check(CardLevels.effects_for(card, 5).size() >= (card["effects"] as Array).size(), "higher levels only add effects for " + id)
	var b := _level_battle("power_shot", 4)
	b.play_card(0)
	check(int(b.mods["ammo"]) == 4, "Power Shot level 4 gives +2 +1 +1 = 4 hits, got %d" % int(b.mods["ammo"]))
	var b0 := _level_battle("power_shot", 3)
	b0.play_card(0)
	check(int(b0.mods["ammo"]) == 3, "Power Shot level 3 has the level 2 bonus only, got %d" % int(b0.mods["ammo"]))
	var b1 := _level_battle("power_shot", 1)
	b1.play_card(0)
	check(int(b1.mods["ammo"]) == 2, "Power Shot level 1 is unchanged")
	var b2 := _level_battle("reload", 4)
	b2.play_card(0)
	check(int(b2.queue[0]["ammo"]) == 5, "Reload level 4 adds a 5-hit ball, got %d" % int(b2.queue[0]["ammo"]))
	var b3 := _level_battle("tidy_up", 5)
	b3.play_card(0)
	check(b3.removed_last.size() == 1 and int(b3.mods["ammo"]) == 4, "Tidy Up level 5 removes 1 barrel and gives +4 hits, got %d and %d" % [b3.removed_last.size(), int(b3.mods["ammo"])])
	var b4 := _level_battle("color_bomb", 5)
	b4.play_card(0)
	check(b4.removed_last.size() == 7, "Color Bomb level 5 removes 5 + 1 + 1 = 7 barrels, got %d" % b4.removed_last.size())
	var b5 := _level_battle("quick_draw", 5)
	var before := b5.hand.size()
	b5.play_card(0)
	check(b5.hand.size() == before - 1 + 2, "Quick Draw level 5 draws 2 cards")
	check(b5.clone().levels == {"quick_draw": 5}, "a cloned battle keeps the levels")
	var sb := Stages.new_battle(0, GameData.starter_deck, 1, {"power_shot": 2})
	check(sb.level_of("power_shot") == 2 and sb.level_of("skip") == 1, "new_battle sets the level table")
	check(Collection.levels_for_battle({"level": {"power_shot": 9, "skip": 1}}) == {"power_shot": 5}, "levels are capped at the maximum")


## 8.7: a preview must equal the real play for every card at every level.
func test_level_parity() -> void:
	for id in GameData.card_order:
		for level in range(1, PackConfig.max_level() + 1):
			for seed_value in [21, 22]:
				var b := Battle.new(GameData.pictures[seed_value % 10]["rows"], [id, id, id], 0.8, 3, seed_value, {}, {"bomb": 2, "ammo": 1, "iron": 3, "curse": 2})
				b.levels = {id: level}
				var pv := b.preview_card(0)
				var after: Battle = pv["battle"]
				b.play_card(0)
				var same := after.board.cells == b.board.cells and after.queue == b.queue and after.hand == b.hand and after.mods == b.mods
				check(same, "preview matches play for %s at level %d" % [id, level])


# ---------- Transcended cards (phase 3) ----------

func test_transcended_cards() -> void:
	var top: Array = []
	for id in GameData.card_order:
		if GameData.cards[id]["rarity"] == "transcended":
			top.append(id)
	check(top.size() == 4, "four Transcended cards, got %d" % top.size())
	for id in ["maelstrom", "davy_ledger", "ghost_compass", "phantom_echo"]:
		check(top.has(id), "Transcended card exists: " + id)
	check(UiKit.RARITY_COLORS.has("transcended"), "Transcended has a rarity color")
	# With real cards in the game, a vault can finally pay out a Transcended card.
	var st := Collection.new_state()
	var rng := _rng(4)
	var seen := {}
	for i in 30:
		for c in Packs.roll_chest(PackConfig.chest("vault"), st, 100, _catalog(), rng):
			if c["rarity"] == "transcended":
				seen[c["id"]] = true
	check(seen.size() == 4, "30 vaults give all four Transcended cards, got %d" % seen.size())


func _board_battle(rows: Array, id: String, level: int = 1) -> Battle:
	var deck: Array = []
	deck.resize(10)
	deck.fill(id)
	var b := Battle.new(rows, deck, 1.5, 3, 5)
	b.levels = {id: level}
	return b


func test_transcended_effects() -> void:
	# Maelstrom: every barrel of the biggest color, but at most 20.
	var rows: Array = []
	for i in 8:
		rows.append("RRRRRRRB")  # 56 red, 8 blue
	var m := _board_battle(rows, "maelstrom")
	m.play_card(0)
	check(m.removed_last.size() == 20, "Maelstrom removes 20 of the biggest color, got %d" % m.removed_last.size())
	var m2 := _board_battle(["RRRRBB", "RRRRBB"], "maelstrom")
	m2.play_card(0)
	check(m2.removed_last.size() == 8 and m2.board.color_counts().has("B") and not m2.board.color_counts().has("R"), "Maelstrom takes the whole color when it has fewer than 20")
	# Jones' Ledger: two wild 5-hit balls at the front.
	var l := _board_battle(["BBBBBBBB", "BBBBBBBB"], "davy_ledger")
	l.queue = [{"color": "R", "ammo": 3}]
	l.play_card(0)
	check(l.queue.size() == 3 and bool(l.queue[0].get("wild", false)) and int(l.queue[0]["ammo"]) == 3 and int(l.queue[1]["ammo"]) == 3, "Ledger adds two 3-hit wild balls")
	check(l.shots_left() == 6, "the two wild balls count as usable shots and the red one does not, got %d" % l.shots_left())
	var before := l.board.cells.duplicate()
	l.fire()
	check(l.board.cells != before and l.removed_last.size() == 3, "a wild ball hits a color it does not match, removed %d" % l.removed_last.size())
	# A wild ball is not thrown out when its own color is gone; a normal one is.
	var l2 := _board_battle(["BBBB"], "skip")
	l2.queue = [{"color": "R", "ammo": 2, "wild": true}, {"color": "R", "ammo": 2}]
	l2._prune_dead_shooters()
	check(l2.queue.size() == 1 and bool(l2.queue[0].get("wild", false)), "only the wild ball survives pruning")
	# Level bonus reaches both balls.
	var l3 := _board_battle(["BBBBBBBB", "BBBBBBBB"], "davy_ledger", 5)
	l3.queue = []
	l3.play_card(0)
	check(l3.queue.size() == 2 and int(l3.queue[0]["ammo"]) == 3 and l3.removed_last.size() == 2, "Ledger level 5 adds 2 barrels instead of hits, removed %d" % l3.removed_last.size())
	# Ghost Compass: a free turn and 2 cards.
	var g := _board_battle(["RRRRRRRR", "RRRRRRRR", "RRRRRRRR"], "ghost_compass")
	g.queue = [{"color": "R", "ammo": 1}, {"color": "R", "ammo": 1}, {"color": "R", "ammo": 1}]
	var turns_before := g.turns
	var hand_before := g.hand.size()
	g.play_card(0)
	check(g.hand.size() == hand_before - 1 + 2, "Ghost Compass draws 2 cards")
	check(int(g.mods["ammo"]) == 3 and g.plays_left == 1, "Ghost Compass gives +3 hits and leaves one more card to play")
	g.fire()
	check(g.turns == turns_before, "a free turn does not use up a turn: %d then %d" % [turns_before, g.turns])
	var g2 := _board_battle(["RRRRRRRR", "RRRRRRRR", "RRRRRRRR"], "skip")
	g2.queue = [{"color": "R", "ammo": 1}, {"color": "R", "ammo": 1}]
	var t2 := g2.turns
	g2.fire()
	check(g2.turns == t2 + 1, "a normal turn counts")
	# A free winning turn does not count either.
	var g3 := _board_battle(["R"], "ghost_compass")
	g3.star3_turns = 1
	g3.star2_turns = 2
	g3.hand = ["ghost_compass"]
	g3.queue = [{"color": "R", "ammo": 1}, {"color": "R", "ammo": 1}]
	g3.turns = 1
	g3.play_card(0)
	g3.fire()
	check(g3.won and g3.turns == 0, "winning on a free turn: turns %d" % g3.turns)
	# Phantom Echo: repeats the last card at +1 level, or draws 1 card.
	var e := _board_battle(["RRRRRRRR", "RRRRRRRR"], "phantom_echo")
	e.hand = ["phantom_echo", "phantom_echo", "phantom_echo"]
	var hand_e := e.hand.size()
	e.play_card(0)
	check(e.hand.size() == hand_e - 1 + 1 and e.last_played == "", "with no last card Phantom Echo draws 1 and records nothing")
	var e2 := _board_battle(["RRRRRRRR", "RRRRRRRR"], "phantom_echo")
	e2.hand = ["power_shot", "phantom_echo", "phantom_echo"]
	e2.play_card(0)
	check(int(e2.mods["ammo"]) == 2 and e2.last_played == "power_shot", "Power Shot adds 2 hits")
	e2.plays_left = 3
	e2.play_card(0)  # Phantom Echo (the hand is now phantom_echo, phantom_echo)
	check(int(e2.mods["ammo"]) == 2 + 3 + 1 and e2.last_played == "power_shot", "Echo repeats Power Shot at level 2 (+3) and adds 1 hit, got %d" % int(e2.mods["ammo"]))
	e2.play_card(0)
	check(int(e2.mods["ammo"]) == 2 + 4 + 4, "a second Echo repeats it again, got %d" % int(e2.mods["ammo"]))
	# The repeat uses the level above the card's level, up to 5.
	var e3 := _board_battle(["RRRRRRRR", "RRRRRRRR"], "phantom_echo")
	e3.levels = {"power_shot": 4, "phantom_echo": 1}
	e3.hand = ["power_shot", "phantom_echo", "phantom_echo"]
	e3.plays_left = 3
	e3.play_card(0)
	var after_ps := int(e3.mods["ammo"])
	e3.play_card(0)
	check(int(e3.mods["ammo"]) - after_ps == 6, "Echo repeats a level 4 card at level 5 (+5 hits) and adds 1, got +%d" % (int(e3.mods["ammo"]) - after_ps))
	e3.levels["power_shot"] = 5
	var b5 := int(e3.mods["ammo"])
	e3.play_card(0)
	check(int(e3.mods["ammo"]) - b5 == 6, "and never above level 5")


## Previews must equal the real play for the new cards too, including Phantom Echo after another card.
func test_echo_parity() -> void:
	for id in ["maelstrom", "davy_ledger", "ghost_compass", "phantom_echo"]:
		for level in range(1, PackConfig.max_level() + 1):
			for seed_value in [31, 32]:
				var b := Battle.new(GameData.pictures[seed_value % 10]["rows"], [id, "power_shot", "reload", id, "color_bomb", id], 0.8, 3, seed_value, {}, {"bomb": 2, "ammo": 1, "iron": 3, "curse": 2})
				b.levels = {id: level, "power_shot": level, "reload": level, "color_bomb": level}
				b.hand = ["power_shot", id, "reload"]
				b.play_card(0)
				var pv := b.preview_card(0)  # the next card (the Transcended one) after a first card
				var after: Battle = pv["battle"]
				b.play_card(0)
				var same := after.board.cells == b.board.cells and after.queue == b.queue and after.hand == b.hand and after.mods == b.mods and after.turns == b.turns and after.last_played == b.last_played
				check(same, "preview matches play for %s at level %d" % [id, level])
				check(after.clone().last_played == b.last_played, "a clone keeps the last played card")


func test_captain_slots() -> void:
	var catalog := _catalog()
	check(Collection.captain_slots(0) == 0 and Collection.captain_slots(49) == 0, "no Captain's Slot before stage 50")
	check(Collection.captain_slots(50) == 1 and Collection.captain_slots(99) == 1, "one slot after stage 50")
	check(Collection.captain_slots(100) == 2, "two slots after stage 100")
	var st := Collection.new_state()
	check(not Collection.equip(st, "maelstrom", 60, catalog), "cannot equip a card you do not own")
	Collection.add_copy(st, "maelstrom", catalog)
	Collection.add_copy(st, "ghost_compass", catalog)
	Collection.add_copy(st, "phantom_echo", catalog)
	check(not Collection.equip(st, "maelstrom", 10, catalog), "no slot before stage 50")
	check(Collection.equip(st, "maelstrom", 60, catalog) and not Collection.equip(st, "maelstrom", 60, catalog), "equip once")
	check(not Collection.equip(st, "ghost_compass", 60, catalog), "one slot is full")
	check(Collection.equip(st, "ghost_compass", 100, catalog) and not Collection.equip(st, "phantom_echo", 100, catalog), "two slots after stage 100")
	check(Collection.equipped_cards(st, 60, catalog) == ["maelstrom"], "only as many as there are slots count")
	check(Collection.equipped_cards(st, 100, catalog) == ["maelstrom", "ghost_compass"], "both count at stage 100")
	check(not Collection.equip(st, "power_shot", 100, catalog), "only Transcended cards go in the slots")
	Collection.unequip(st, "maelstrom")
	check(Collection.equipped_cards(st, 100, catalog) == ["ghost_compass"], "unequip frees a slot")
	# The stage deck: no Transcended card unless equipped, and never twice.
	var base: Array = Stages.deck_for(59)
	var deck := Collection.deck_with_equipped(base, st, 100, catalog)
	check(deck.size() == base.size() + 1 and deck.has("ghost_compass") and not deck.has("maelstrom"), "stage deck gets the equipped card")
	var again := Collection.deck_with_equipped(deck, st, 100, catalog)
	check(again.size() == deck.size(), "building the deck twice does not duplicate (Try again)")
	check(Collection.deck_with_equipped(base, Collection.new_state(), 100, catalog).size() == base.size(), "nothing equipped, nothing added")
	# A stale equipped id (not owned any more) is ignored.
	st["equipped"] = ["maelstrom"]
	st["owned"].erase("maelstrom")
	check(Collection.equipped_cards(st, 100, catalog).is_empty(), "an equipped card that is not owned is ignored")
