extends SceneTree
## Opens every pack screen in a real Main scene to catch runtime errors (headless, no pictures).
## Run: godot --headless --path prototype --script res://tests/screens_smoke.gd

var failures: int = 0


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("FAIL: ", msg)


func _initialize() -> void:
	GameData.ensure_loaded()
	SaveData.path = "user://smoke_save.cfg"
	SaveData.reset()
	SaveData.tutorial_done = true
	for k in 62:
		SaveData.record(k, 2)
	var st := SaveData.pack_state()
	for c in PackConfig.chests:
		Packs.grant(st, str(c["id"]), 2)
	st["doubloons"] = 5000
	st["pearls"] = 500
	for id in ["power_shot", "row_strike", "prism"]:
		st["spare"][id] = 4
	for id in GameData.card_order:
		if GameData.cards[id]["rarity"] == "transcended":
			Collection.add_copy(st, id, GameData.cards)
	SaveData.save()
	var scene: PackedScene = load(str(ProjectSettings.get_setting("application/run/main_scene")))
	var main: Control = scene.instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	var packs: PackScreens = main.packs
	check(packs != null, "Main builds the pack screens")
	packs.show_treasury()
	await process_frame
	await process_frame
	packs.show_market()
	await process_frame
	await process_frame
	for f in ["all", "ready", "common", "rare", "epic", "legendary", "transcended"]:
		packs.show_cargo(Callable(), f)
		await process_frame
	packs.show_cargo()
	await process_frame
	packs._show_detail("prism")
	await process_frame
	packs._show_detail("maelstrom")
	await process_frame
	packs._show_detail("blast")  # a card that is not unlocked yet at this progress is also fine
	await process_frame
	packs._close_detail()
	main.show_menu()
	await process_frame
	main.show_map(10)
	await process_frame
	# Elite stages: pop-up, first-time explanation (once) and the two-card hand of Short Hand.
	for i in [4, 14, 24]:
		main._open_popup(i)
		await process_frame
		main._close_popup()
	main._begin_stage(24, Stages.deck_for(24))
	await process_frame
	await process_frame
	check(main.battle.hand.size() == 2, "Short Hand deals two cards")
	check(main._intro_open != null and SaveData.special_seen("rule_short"), "the rule is explained the first time")
	main._intro_closed.emit()
	await process_frame
	check(main._intro_open == null, "the explanation closes")
	main._begin_stage(24, Stages.deck_for(24))
	await process_frame
	await process_frame
	check(main._intro_open == null, "the rule is explained only once")
	main.show_menu()
	await process_frame
	# Open a chest and let the reveal run on its own (--auto-tap is read from the command line).
	var res := Packs.open_saved("coffer")
	check(bool(res["ok"]), "a coffer opens")
	packs.show_opening()
	for i in 3:
		await process_frame
	main.show_menu()
	await process_frame
	await _last_shot(main)
	await _daily(main)
	await _boss(main)
	await _album(main)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://smoke_save.cfg"))
	print("Screens smoke test failures: ", failures)
	quit(1 if failures > 0 else 0)


func _lose_with(main: Control, barrels: int) -> void:
	var b: Battle = main.battle
	var standing := 0
	for y in b.board.h:
		for x in b.board.w:
			if b.board.get_c(x, y) != "":
				standing += 1
				if standing > barrels:
					b.board.remove_at(x, y)
	b.queue = []
	b.over = true
	main.busy = true
	main._on_battle_over()


## Captain's Log: every page builds, a cleared picture opens the stage pop-up, a reward is claimed once.
func _album(main: Control) -> void:
	for p in Album.pages():
		main.album.show(p)
		await process_frame
	main.album.show(0)
	await process_frame
	var tiles: Array = main.screen.find_children("*", "Button", true, false).filter(func(n): return n.has_meta("stage"))
	check(tiles.size() == 10 and int(tiles[0].get_meta("stars")) == SaveData.stars(0), "page 1 shows ten pictures with their stars")
	tiles[0].pressed.emit()
	await process_frame
	check(main.popup != null, "a cleared picture opens the stage pop-up")
	main._close_popup()
	var gold := int(SaveData.pack_state()["doubloons"])
	var claim: Node = main.screen.find_child("claim_complete", true, false)
	check(claim != null, "a full page offers its reward")
	if claim != null:
		claim.pressed.emit()
		await process_frame
		await process_frame
		check(int(SaveData.pack_state()["doubloons"]) == gold + Album.COMPLETE_DOUBLOONS, "claiming pays 100")
		check(main.screen.find_child("claim_complete", true, false) == null, "and only once")
	main.show_menu()
	await process_frame


## Boss stage: explanation once, the bar, and a strike after the third shot.
func _boss(main: Control) -> void:
	main._begin_stage(9, Stages.deck_for(9))
	await process_frame
	check(main.boss_bar != null and main._intro_open != null, "a boss stage has its bar and explains the rule")
	main._intro_closed.emit()
	await process_frame
	var b: Battle = main.battle
	b.queue = [{"color": b.board.most_common(), "ammo": 1}]
	for k in 12:
		b.queue.append({"color": b.board.most_common(), "ammo": 1})
	for shot in 3:
		main.selected = -1
		main.busy = false
		main._on_fire_pressed()
		while main.busy:
			if main._intro_open != null:
				main._intro_closed.emit()
			await process_frame
	check(b.shots_fired == 3, "three shots fired")
	check(main.boss_bar.words() == "strikes in 3 shots", "the counter starts again after the strike: " + main.boss_bar.words())
	main._begin_stage(1, Stages.deck_for(1))
	await process_frame
	check(main.boss_bar == null, "no bar on an ordinary stage")
	main.show_menu()
	await process_frame


## Daily Haul: start screen, a battle, restart, and the score screen.
func _daily(main: Control) -> void:
	main.daily.show_start()
	await process_frame
	var today := SaveData.today()
	main._begin_daily(today)
	await process_frame
	check(main._daily_date == today and main.battle.hand.size() == 3, "the daily battle starts")
	main._options_restart()
	await process_frame
	check(main._daily_date == today, "restarting stays in the daily")
	var gold := int(SaveData.pack_state()["doubloons"])
	var stars := SaveData.total_stars()
	_lose_with(main, 3)
	await process_frame
	check(main._offer == null and not SaveData.daily_entry(today).is_empty(), "no Last Shot in the daily; the score is kept")
	check(int(SaveData.pack_state()["doubloons"]) == gold and SaveData.total_stars() == stars, "a loss pays nothing and no stars change")
	main._begin_daily(today)
	await process_frame
	main.battle.won = true
	main.battle.over = true
	main._on_battle_over()
	await process_frame
	check(int(SaveData.pack_state()["doubloons"]) == gold + DailyHaul.REWARD and SaveData.total_stars() == stars, "the first win pays 20 and no stars change")
	main._begin_stage(1, Stages.deck_for(1))
	await process_frame
	check(main._daily_date == "", "a stage is not a daily")
	main.show_menu()
	await process_frame


## Last Shot: offered after a close loss, taken once, then the free use of the day is gone.
func _last_shot(main: Control) -> void:
	main._begin_stage(1, Stages.deck_for(1))
	await process_frame
	_lose_with(main, 3)
	await process_frame
	check(main._offer != null, "a close loss offers the Last Shot")
	main._take_last_shot()
	await process_frame
	check(main._offer == null and not main.battle.over and not main.busy and main.battle.queue.size() == 1, "taking it resumes the battle")
	check(SaveData.last_shot_left() == 0, "the daily use is spent")
	main._begin_stage(1, Stages.deck_for(1))
	await process_frame
	_lose_with(main, 3)
	await process_frame
	check(main._offer == null, "no offer once the day's shot is used")
	main.show_menu()
	await process_frame
