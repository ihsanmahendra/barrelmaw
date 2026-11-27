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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://smoke_save.cfg"))
	print("Screens smoke test failures: ", failures)
	quit(1 if failures > 0 else 0)
