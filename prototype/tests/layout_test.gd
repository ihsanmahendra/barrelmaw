extends SceneTree
## Builds every screen and checks that text, buttons and panels stay inside the part of the window a phone really
## shows: not under the notch or the home bar, not past the sides. Run it at several window shapes:
##   godot --path . --resolution 390x844 --script res://tests/layout_test.gd
## The notch is faked with SafeArea.debug_insets below, so the check does not need a phone.

var failures: int = 0
var main: Control
const FAKE_INSETS := Vector4(0.0, 64.0, 0.0, 34.0)  # a phone with a notch and a home bar, in viewport units
const CHECK_TYPES: Array = ["Label", "Button", "CardView", "PanelContainer", "RibbonLabel", "ChestView"]


func _initialize() -> void:
	GameData.ensure_loaded()
	SafeArea.debug_insets = FAKE_INSETS
	SaveData.path = "user://layout_test_save.cfg"
	SaveData.reset()
	SaveData.tutorial_done = true
	for k in 24:
		SaveData.record(k, 2)
	var st := SaveData.pack_state()
	for c in PackConfig.chests:
		Packs.grant(st, str(c["id"]), 2)
	st["doubloons"] = 5000
	st["pearls"] = 300
	var scene: PackedScene = load(str(ProjectSettings.get_setting("application/run/main_scene")))
	main = scene.instantiate()
	root.add_child(main)
	await _frames(4)
	await _run()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://layout_test_save.cfg"))
	print("Layout test at %s (viewport %s): %d problems" % [str(root.size), str(root.get_visible_rect().size), failures])
	quit(1 if failures > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _scrolled(node: Node) -> bool:
	var p := node.get_parent()
	while p != null:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false


func _check(label: String, roots: Array) -> void:
	var vp := root.get_visible_rect()
	var safe := Rect2(Vector2(FAKE_INSETS.x, FAKE_INSETS.y), vp.size - Vector2(FAKE_INSETS.x + FAKE_INSETS.z, FAKE_INSETS.y + FAKE_INSETS.w)).grow(1.5)
	var bad := 0
	for r in roots:
		for n in _all(r):
			if not (n is Control) or not (n as Control).is_visible_in_tree() or _scrolled(n):
				continue
			if not CHECK_TYPES.has(n.get_class()) and not CHECK_TYPES.has(str(n.get_script().get_global_name() if n.get_script() != null else "")):
				continue
			var rect := (n as Control).get_global_rect()
			if rect.size.x < 2.0 or rect.size.y < 2.0 or (n as Control).modulate.a < 0.05:
				continue
			if n is Label and (n as Label).text.strip_edges() == "":
				continue
			if not safe.encloses(rect):
				bad += 1
				failures += 1
				print("  %s: %s %s is outside the safe area (%s)" % [label, n.get_class(), n.name, str(rect)])
				if bad >= 4:
					return


## Text drawn on top of a picture has to sit on the part of the picture meant for it. The ribbon's red band is
## the top of its image (the tails hang below), so RibbonLabel.BAND_CENTER must match the band in the image.
func _check_ribbon_art() -> void:
	var tex := UiKit.ui_texture("ribbon")
	if tex == null:
		return
	var img := tex.get_image()
	var mid := img.get_width() / 2
	var top := -1
	var bottom := -1
	for y in img.get_height():
		if img.get_pixel(mid, y).a > 0.15:
			if top < 0:
				top = y
			bottom = y
	var measured := (float(top + bottom) / 2.0) / float(img.get_height())
	if absf(measured - RibbonLabel.BAND_CENTER) > 0.05:
		failures += 1
		print("  ribbon: BAND_CENTER %.2f but the red band's centre in the picture is %.2f" % [RibbonLabel.BAND_CENTER, measured])


## Pictures drawn on the map must not cover each other: the stage ship and its reward chest, and the last
## island's treasure box and the compass (whose "N" must also stay clear of the wooden frame).
func _check_map_art() -> void:
	var map: MapView = main.map_view
	var side := Rect2(Vector2.ZERO, map.size)
	for i in Stages.TOTAL:
		var ship := map.ship_rect(i)
		if not Rect2(side.position, side.size).encloses(ship):
			failures += 1
			print("  map: the ship at stage %d leaves the map (%s)" % [i + 1, str(ship)])
			break
		if map.reward_chests.has(i) and ship.intersects(map.chest_rect(i)):
			failures += 1
			print("  map: the ship covers the reward chest of stage %d" % (i + 1))
			break
	var compass := map.compass_rect()
	if compass.intersects(map.treasure_rect()):
		failures += 1
		print("  map: the treasure box %s overlaps the compass %s" % [str(map.treasure_rect()), str(compass)])
	if compass.position.y < 9.0 or not side.encloses(compass):
		failures += 1
		print("  map: the compass is under the map frame (%s)" % str(compass))


## "Tap the chest to open it" starts below the chest and its shadow.
func _check_chest_hint() -> void:
	var chest: ChestView = null
	var hint: Label = null
	for n in _all(main.screen):
		if n is ChestView:
			chest = n
		if n is Label and (n as Label).text.begins_with("Tap the chest"):
			hint = n
	if chest == null or hint == null:
		failures += 1
		print("  opening: chest or hint not found")
		return
	var bottom := chest.global_position.y + chest.art_bottom()
	if hint.global_position.y < bottom:
		failures += 1
		print("  opening: the hint starts at %.0f, the chest reaches %.0f" % [hint.global_position.y, bottom])


## Paper panels must keep their content off the curled edges: content margin at least half the edge depth.
func _check_paper_margins(label: String, roots: Array) -> void:
	for r in roots:
		for n in _all(r):
			if not (n is PanelContainer) or not (n as Control).is_visible_in_tree():
				continue
			var sb := (n as PanelContainer).get_theme_stylebox("panel")
			if sb is StyleBoxTexture:
				var t := sb as StyleBoxTexture
				if t.content_margin_top < t.texture_margin_top * 0.5 or t.content_margin_bottom < t.texture_margin_bottom * 0.5:
					failures += 1
					print("  %s: paper panel %s puts content on the curled edge (margins %.0f/%.0f, edge %.0f/%.0f)" % [
						label, n.name, t.content_margin_top, t.content_margin_bottom, t.texture_margin_top, t.texture_margin_bottom])


func _all(node: Node, out: Array = []) -> Array:
	out.append(node)
	for c in node.get_children():
		_all(c, out)
	return out


func _screen(label: String, build: Callable, wait: int = 8) -> void:
	build.call()
	await _frames(wait)
	var roots: Array = [main.screen, main.mute_button]
	if main.gear_button.visible:
		roots.append(main.gear_button)
	_check(label, roots)
	_check_paper_margins(label, roots)


## Elite stages: the pop-up with the rule, the first-time explanation, a two-card hand and the longest card texts.
func _elite_screens() -> void:
	for i in [4, 14, 24]:
		main.show_map(i)
		await _frames(4)
		main._open_popup(i)
		await _frames(30)
		_check("stage %d pop-up" % (i + 1), [main.popup])
		main._close_popup()
		main._show_rule_intro(i)
		await _frames(30)
		_check("%s explanation" % Stages.elite_name(i), [main._intro_open])
		main._intro_closed.emit()
		await _frames(2)
	await _screen("short hand battle", func() -> void: main._begin_stage(24, Stages.deck_for(24)), 90)
	if main._intro_open != null:
		failures += 1
		print("  the rule explanation showed again after it was seen")
	await _screen("longest card texts", func() -> void:
		main.battle.hand = ["ghost_compass", "davy_ledger"]
		main.battle.levels = {"ghost_compass": 5, "davy_ledger": 5}
		main.battle.drawn_total = 0
		main._seen_drawn = 0
		main._refresh())


func _run() -> void:
	_check_ribbon_art()
	var packs: PackScreens = main.packs
	await _screen("menu", func() -> void: main.show_menu())
	await _screen("how to play", func() -> void: main.show_howto())
	await _screen("map", func() -> void: main.show_map(20))
	_check_map_art()
	await _screen("opening", func() -> void: packs.open_and_show("crate"))
	_check_chest_hint()
	await _screen("treasury", func() -> void: packs.show_treasury())
	await _screen("cargo hold", func() -> void: packs.show_cargo())
	await _screen("market", func() -> void: packs.show_market())
	await _screen("unlock", func() -> void: main.show_unlock(10))
	await _screen("battle", func() -> void: main._begin_stage(15, Stages.deck_for(15)), 14)
	main._open_options()
	await _frames(4)
	_check("options (in battle)", [main.options_layer])
	main._close_options()
	await _screen("result", func() -> void:
		main._last_rewards = {"doubloons": 100, "chests": {"iron": 2, "crate": 1}}
		main.battle = Stages.new_battle(20, Stages.deck_for(20), 1)
		main.battle.queue = [{"color": "R", "ammo": 9}]
		main.battle.over = true
		main.battle.won = true
		main.show_stage_result(true))
	await _elite_screens()
	await _screen("battle before the Last Shot", func() -> void: main._begin_stage(1, Stages.deck_for(1)), 14)
	main.battle.queue = []
	main.battle.over = true
	var standing := 0
	for y in main.battle.board.h:
		for x in main.battle.board.w:
			if main.battle.board.get_c(x, y) != "":
				standing += 1
				if standing > 5:
					main.battle.board.remove_at(x, y)
	main._offer_last_shot()
	await _frames(30)
	_check("Last Shot offer", [main._offer])
	_check_paper_margins("Last Shot offer", [main._offer])
	main._close_offer()
	await _screen("tutorial", func() -> void: main.start_tutorial(), 14)
