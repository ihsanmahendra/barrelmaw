class_name FeatureTests
extends RefCounted
## Headless checks for the features after Rebalance v1 (design/gdd/next-features.md). Run by run_tests.gd.

var failures: int = 0


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("FAIL: ", msg)


func run() -> void:
	var path := SaveData.path
	SaveData.path = "user://feature_test_save.cfg"
	SaveData.reset()
	test_last_shot()
	test_combo()
	test_daily()
	test_boss_rules()
	SaveData.reset()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.path))
	SaveData.path = path


## A battle on one row of `barrels` red barrels, already lost with an empty queue.
func _lost(barrels: int) -> Battle:
	var b := Battle.new(["R".repeat(barrels)], ["skip", "skip", "skip", "skip", "skip", "skip"], 1.0, 3, 7)
	b.queue = [{"color": "R", "ammo": 0}]
	b.fire()
	return b


## design/gdd/last-shot.md section 8.
func test_last_shot() -> void:
	var at5 := _lost(5)
	check(at5.over and not at5.won and at5.can_last_shot(), "offered with 5 barrels left")
	check(not _lost(6).can_last_shot(), "not offered with 6 barrels left")
	var turns := at5.turns
	check(at5.take_last_shot(), "the shot can be taken")
	check(not at5.over and at5.queue.size() == 1 and bool(at5.queue[0].get("wild", false)) and int(at5.queue[0]["ammo"]) == 3, "one wild 3-hit cannonball")
	check(at5.turns == turns + 1 and at5.hand.size() == 3, "a new turn starts with cards drawn")
	at5.queue[0]["color"] = "B"  # no blue barrel anywhere: a wild ball hits anyway
	at5.fire()
	check(at5.board.count() == 2, "the wild ball hits any color, %d left" % at5.board.count())
	check(at5.over and not at5.won and not at5.can_last_shot() and not at5.take_last_shot(), "never twice in one attempt")
	var win := _lost(3)
	win.star3_turns = 99
	win.star2_turns = 99
	win.take_last_shot()
	check(win.projected_stars() == 1 and win.star_limit() == -1, "the stars box shows 1 star after the shot")
	check(win.clone().last_shot_used, "a cloned battle remembers the Last Shot")
	win.fire()
	check(win.won and win.star_rating() == 1, "a win after it records 1 star")
	SaveData.record(0, 3)
	SaveData.record(0, win.star_rating())
	check(SaveData.stars(0) == 3, "it never lowers a better saved result")
	check(_lost(5).can_last_shot(), "a new attempt may be offered again")
	# One free use per day; saved; unused days do not stack and turning the clock back gives nothing.
	check(SaveData.last_shot_left("2026-11-27") == 1, "one free shot a day")
	check(SaveData.use_last_shot("2026-11-27") and SaveData.last_shot_left("2026-11-27") == 0, "using it spends it")
	check(not SaveData.use_last_shot("2026-11-27"), "no second use the same day")
	SaveData.reload_from_disk()
	check(SaveData.last_shot_left("2026-11-27") == 0, "reloading the save does not restore it")
	check(SaveData.last_shot_left("2026-11-26") == 0, "a clock turned back does not restore it")
	check(SaveData.last_shot_left("2026-11-30") == 1, "the next day has one again, not several")


## design/gdd/combo-feedback.md section 4.
func test_combo() -> void:
	for pair in [[0, 0], [6, 0], [14, 0], [15, 1], [26, 1], [27, 2], [39, 2], [40, 3], [90, 3]]:
		check(ComboFx.tier_of(pair[0]) == pair[1], "%d barrels is combo tier %d, got %d" % [pair[0], pair[1], ComboFx.tier_of(pair[0])])


## design/gdd/daily-challenge.md section 8.
func test_daily() -> void:
	var pool := DailyHaul.pool()
	check(pool.size() == 48, "48 ordinary stages from 41 to 99, got %d" % pool.size())
	for i in pool:
		check(not Stages.is_boss(i) and not Stages.is_elite(i) and i >= 40 and i <= 98, "pool stage %d is ordinary" % (i + 1))
	var seen := {}
	var first_day := DailyHaul.days_since_1970("2026-11-27")
	for k in 48:
		var date := Time.get_date_string_from_unix_time((first_day + k) * 86400)
		seen[DailyHaul.stage_index(date)] = true
	check(seen.size() == 48, "no picture repeats within 48 days, %d different" % seen.size())
	# The same date gives the same picture, queue, specials and first three hands.
	var a := DailyHaul.new_battle("2026-11-27")
	var b := DailyHaul.new_battle("2026-11-27")
	check(a.board.cells == b.board.cells and a.board.special == b.board.special and a.queue == b.queue, "same board, specials and queue")
	check(a.draw_pile.size() + a.hand.size() == 34, "the 34 stage cards")
	for turn in 3:
		check(a.hand == b.hand, "same hand on turn %d" % (turn + 1))
		a.fire()
		b.fire()
	check(a.levels.is_empty() and DailyHaul.new_battle("2026-11-28").queue != DailyHaul.new_battle("2026-11-27").queue, "no card levels; another day differs")
	for id in a.draw_pile + a.hand + a.discard:
		check(GameData.cards[id]["rarity"] != "transcended", "no Transcended cards in the daily")
	# Score: first attempt is shared, best improves, reward once per date.
	var history := {}
	var lost := {"won": false, "turns": 6, "hits": 0}
	var slow := {"won": true, "turns": 9, "hits": 1}
	var quick := {"won": true, "turns": 7, "hits": 0}
	check(DailyHaul.record(history, "2026-11-27", lost) == 0, "a loss pays nothing")
	check(DailyHaul.record(history, "2026-11-27", slow) == 20, "the first win pays 20")
	check(DailyHaul.record(history, "2026-11-27", quick) == 0, "paid once a date")
	check(history["2026-11-27"]["first"] == lost and history["2026-11-27"]["best"] == quick, "first attempt kept, best updated")
	check(DailyHaul.better({"won": true, "turns": 7, "hits": 2}, quick), "more hits left breaks a tie")
	check(DailyHaul.share_text("2026-11-27", quick) == "Barrelmaw daily 2026-11-27: cleared in 7 turns (par %d)" % DailyHaul.par("2026-11-27"), "share text")
	SaveData.reset()
	check(not SaveData.daily_haul_open(), "closed on a new save")
	SaveData.record(9, 1)
	check(SaveData.daily_haul_open(), "open after stage 10")
	SaveData.daily_finish("2026-11-27", slow)
	SaveData.reload_from_disk()
	check(SaveData.daily_finish("2026-11-27", quick) == 0 and int(SaveData.pack_state()["doubloons"]) == 20, "a reload does not pay again")


## design/gdd/boss-rules.md: rules, values and section 8.
const BOSS_VALUES: Dictionary = {  # stage -> [rule, slack, 3-star turns, 2-star turns]
	10: ["ghost", 0.62, 10, 12], 20: ["armor", 0.51, 13, 15], 30: ["curse", 0.26, 7, 9], 40: ["ghost", 0.16, 6, 8],
	50: ["armor", 0.17, 10, 12], 60: ["curse", 0.15, 9, 11], 70: ["ghost", 0.08, 8, 10], 80: ["armor", 0.08, 7, 9],
	90: ["curse", 0.01, 7, 9], 100: ["ghost", 0.08, 9, 11],
}


func test_boss_rules() -> void:
	for i in Stages.TOTAL:
		check(Stages.is_boss(i) == (Stages.boss_rule(i) != ""), "stage %d: every boss and no other stage has a strike" % (i + 1))
	for stage in BOSS_VALUES:
		var i: int = stage - 1
		var row: Array = BOSS_VALUES[stage]
		check(Stages.boss_rule(i) == row[0] and is_equal_approx(Stages.slack(i), row[1]), "stage %d rule and slack" % stage)
		check(Stages.star3_turns(i) == row[2] and Stages.star2_turns(i) == row[3], "stage %d star turns" % stage)
		check(Stages.strike_size(i) >= 2, "a strike affects at least 2 barrels")
	# Strikes after shots 3, 6 and 9 only, and never after the winning shot.
	for stage in [10, 20, 30]:
		var i: int = stage - 1
		var rule := Stages.boss_rule(i)
		var b := Stages.new_battle(i, Stages.deck_for(i), 11)
		var color := b.board.most_common()
		b.queue = []
		for k in 12:
			b.queue.append({"color": color, "ammo": 1})  # not wild: Ghost Tide only raises colors still queued
		for shot in range(1, 10):
			b.fire()
			var struck := not b.strike_last.is_empty()
			check(struck == (shot % 3 == 0), "stage %d: strike after shot %d is %s" % [stage, shot, str(shot % 3 == 0)])
			if struck:
				check(b.strike_last.size() <= Stages.strike_size(i), "no more than the strike size")
				for s in b.strike_last:
					var p: Vector2i = s["pos"]
					if rule == "ghost":
						check(b.board.get_c(p.x, p.y) != "" and b.board.get_special(p.x, p.y) == "", "a barrel rose again, plain")
					else:
						check(b.board.get_special(p.x, p.y) == ("iron" if rule == "armor" else "curse"), "a plain barrel changed")
		# Preview equals play for every card, and previews never strike.
		for id in GameData.card_order:
			var c := Stages.new_battle(i, [id, id, id], 21)
			c.shots_fired = 2
			var cells: Array = c.board.cells.duplicate()
			var shown := c.preview_targets()
			check(c.board.cells == cells, "preview_targets does not strike")
			var after: Battle = c.preview_card(0)["battle"]
			c.play_card(0)
			check(after.board.cells == c.board.cells and after.board.special == c.board.special and after.queue == c.queue
				and after.shots_fired == c.shots_fired and after.boss_rule == rule, "preview matches play for %s on stage %d" % [id, stage])
			check(shown.size() >= 0, "preview ran")
	var win := Stages.new_battle(9, Stages.deck_for(9), 3)
	win.shots_fired = 2
	for y in win.board.h:
		for x in win.board.w:
			win.board.remove_at(x, y)
	win.board.cells[0] = "R"
	win.queue = [{"color": "R", "ammo": 1, "wild": true}, {"color": "R", "ammo": 1}]
	win.fire()
	check(win.won and win.strike_last.is_empty(), "no strike after the winning shot")
