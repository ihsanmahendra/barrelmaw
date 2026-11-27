extends SceneTree
## Guards against screens getting slower again: draw calls per frame stay within a budget, only the shimmering
## cards run every frame, and art drawn from a cached texture looks the same as art drawn directly.
##   godot --path . --resolution 540x960 --script res://tests/perf_budget_test.gd   (needs a window, not --headless)

# Draw calls per frame. Measured values were roughly two thirds of these when the budgets were set.
const BUDGETS: Dictionary = {"menu": 220, "map": 170, "treasury": 160, "cargo": 220, "battle": 700}

var failures: int = 0
var main: Control


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	GameData.ensure_loaded()
	SaveData.path = "user://perf_budget_save.cfg"
	SaveData.reset()
	SaveData.tutorial_done = true
	for k in 60:
		SaveData.record(k, 2)
	for kind in Board.SPECIALS:
		SaveData.mark_special_seen(kind)
	var st := SaveData.pack_state()
	for c in PackConfig.chests:
		Packs.grant(st, str(c["id"]), 2)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run()


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _screen(label: String, build: Callable) -> void:
	build.call()
	await _wait(1.5)
	var drawn := Engine.get_frames_drawn()
	var calls := 0
	for i in 30:
		await process_frame
		calls += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	calls /= 30
	check(Engine.get_frames_drawn() - drawn >= 20, label + ": the window is not being drawn, keep it visible")
	print("%-10s %5d draw calls (budget %d)" % [label, calls, BUDGETS[label]])
	check(calls <= BUDGETS[label], "%s needs %d draw calls, budget %d" % [label, calls, BUDGETS[label]])


func _check_card_processing(node: Node) -> void:
	if node is CardView:
		var shimmers: bool = GameData.cards[node.card_id]["rarity"] == "transcended"
		if node.is_processing() != shimmers:
			check(false, "card %s processing=%s" % [node.card_id, node.is_processing()])
			return
	for c in node.get_children():
		_check_card_processing(c)


## A card being dealt grows from small to full size; that must not paint a texture per step.
func _check_animated_cards() -> void:
	var cards: Array = main.screen.find_children("*", "CardView", true, false)
	check(not cards.is_empty(), "no cards in battle to animate")
	var before := BakedArt._cache.size()
	for step in 12:
		for card in cards:
			card.scale = Vector2.ONE * (0.3 + 0.07 * step)
			card.queue_redraw()
		await process_frame
	check(BakedArt._cache.size() == before, "scaling cards made %d new textures" % (BakedArt._cache.size() - before))


## Share of pixels that differ clearly between art drawn directly and from its cached texture.
func _difference(paint_direct: Callable, paint_cached: Callable) -> float:
	var shots: Array = []
	for paint in [paint_direct, paint_cached]:
		var pad := ColorRect.new()
		pad.color = Color("2278a0")
		pad.size = Vector2(200, 200)
		root.add_child(pad)
		var art := Control.new()
		art.draw.connect(paint.bind(art))
		pad.add_child(art)
		await _wait(0.5)
		await RenderingServer.frame_post_draw
		var scale := root.get_final_transform().get_scale().x
		shots.append(root.get_texture().get_image().get_region(Rect2i(0, 0, int(200 * scale), int(200 * scale))))
		pad.queue_free()
		await _wait(0.1)
	var a: Image = shots[0]
	var b: Image = shots[1]
	var off := 0
	for y in a.get_height():
		for x in a.get_width():
			var d := a.get_pixel(x, y) - b.get_pixel(x, y)
			if maxf(absf(d.r), maxf(absf(d.g), absf(d.b))) > 0.15:
				off += 1
	return float(off) / float(a.get_width() * a.get_height())


func _check_cached_art() -> void:
	var chest := await _difference(
		func(c: Control) -> void: ChestArt.draw(c, Vector2(100, 100), 80.0, "gilded"),
		func(c: Control) -> void: ChestArt.draw_still(c, Vector2(100, 100), 80.0, "gilded"))
	check(chest < 0.01, "cached chest differs in %.1f%% of pixels" % (chest * 100.0))
	var light := Color(0.52, 0.62, 0.9)  # the night tint
	var decor := await _difference(
		func(c: Control) -> void: MapDecor.draw(c, Vector2(100, 100), 2, 0.0, light),
		func(c: Control) -> void: MapDecor.draw_still(c, Vector2(100, 100), 2, light))
	check(decor < 0.01, "cached map decoration differs in %.1f%% of pixels" % (decor * 100.0))


func _run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_move_to_foreground()
	await _wait(1.0)
	var packs: PackScreens = main.packs
	await _screen("menu", func() -> void: main.show_menu())
	await _screen("map", func() -> void: main.show_map(70))
	await _screen("treasury", func() -> void: packs.show_treasury())
	await _screen("cargo", func() -> void: packs.show_cargo())
	_check_card_processing(main.screen)
	await _screen("battle", func() -> void: main._begin_stage(48, Stages.deck_for(48)))
	_check_card_processing(main.screen)
	await _check_animated_cards()
	main.visible = false
	await _check_cached_art()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://perf_budget_save.cfg"))
	print("Performance budget failures: ", failures)
	quit(1 if failures > 0 else 0)
