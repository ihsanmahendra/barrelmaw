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


func _run() -> void:
	var packs: PackScreens = main.packs
	await _screen("menu", func() -> void: main.show_menu())
	await _screen("how to play", func() -> void: main.show_howto())
	await _screen("map", func() -> void: main.show_map(20))
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
	await _screen("tutorial", func() -> void: main.start_tutorial(), 14)
