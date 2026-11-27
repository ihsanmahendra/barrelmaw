extends SceneTree
## Drags a finger over every scrolling screen, starting on buttons, cards, panels and gaps, and checks that the
## list scrolls and that nothing was tapped by accident. Touch input is sent the way a phone sends it: touch
## events plus the mouse events Godot emulates from them.
## Run in a real 540x960 window (touch positions are in pixels, so other sizes or --headless give false failures):
##   godot --path prototype --resolution 540x960 --script res://tests/scroll_test.gd

var failures: int = 0
var main: Control
var _pos: Vector2 = Vector2.ZERO
var _scroll_at_lift: int = 0


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("FAIL: ", msg)


func _initialize() -> void:
	GameData.ensure_loaded()
	SaveData.path = "user://scroll_test_save.cfg"
	SaveData.reset()
	SaveData.tutorial_done = true
	for k in 62:
		SaveData.record(k, 2)
	var st := SaveData.pack_state()
	for c in PackConfig.chests:
		Packs.grant(st, str(c["id"]), 3)
	st["doubloons"] = 5000
	st["pearls"] = 900
	for id in ["power_shot", "row_strike", "prism"]:
		st["spare"][id] = 4
	for id in GameData.card_order:
		if GameData.cards[id]["rarity"] == "transcended":
			Collection.add_copy(st, id, GameData.cards)
	SaveData.save()
	var scene: PackedScene = load(str(ProjectSettings.get_setting("application/run/main_scene")))
	main = scene.instantiate()
	root.add_child(main)
	await _frames(4)
	await _run()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://scroll_test_save.cfg"))
	print("Scroll test failures: ", failures)
	quit(1 if failures > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _send_touch(pressed: bool, pos: Vector2) -> void:
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.pressed = pressed
	t.position = pos
	root.push_input(t)
	var m := InputEventMouseButton.new()  # what Godot emulates from the touch
	m.button_index = MOUSE_BUTTON_LEFT
	m.pressed = pressed
	m.position = pos
	m.global_position = pos
	m.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(m)


func _send_move(pos: Vector2, rel: Vector2) -> void:
	var d := InputEventScreenDrag.new()
	d.index = 0
	d.position = pos
	d.relative = rel
	root.push_input(d)
	var mm := InputEventMouseMotion.new()
	mm.position = pos
	mm.global_position = pos
	mm.relative = rel
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(mm)


## A finger drag from `from` by `delta`, one step per frame, then lift. If `watch` is given, its scroll position
## right before the finger lifts is kept in `_scroll_at_lift`.
func _drag(from: Vector2, delta: Vector2, steps: int = 12, watch: ScrollContainer = null) -> void:
	_pos = from
	_send_touch(true, from)
	await process_frame
	for i in steps:
		var rel := delta / float(steps)
		_pos += rel
		_send_move(_pos, rel)
		await process_frame
	if watch != null:
		_scroll_at_lift = watch.scroll_vertical
	_send_touch(false, _pos)
	await _frames(3)


## A tap: touch down and up in the same place.
func _tap(ctl: Control) -> void:
	var p := ctl.get_global_rect().get_center()
	_send_touch(true, p)
	await process_frame
	_send_touch(false, p)
	await _frames(3)


func _all(node: Node, out: Array = []) -> Array:
	out.append(node)
	for c in node.get_children():
		_all(c, out)
	return out


func _first(node: Node, test: Callable) -> Control:
	for n in _all(node):
		if n is Control and (n as Control).is_visible_in_tree() and test.call(n):
			return n
	return null


## Drags up by 240 px from the center of `from_ctl` and checks the list moved.
func _scroll_case(label: String, scroll: ScrollContainer, from_ctl: Control, dy: float = 240.0) -> void:
	if from_ctl == null:
		check(false, "%s: no control to start from" % label)
		return
	await _frames(2)
	var start := from_ctl.get_global_rect().get_center()
	# Stay inside the visible part of the list.
	var area := scroll.get_global_rect()
	start.y = clampf(start.y, area.position.y + 20.0, area.end.y - dy - 10.0)
	start.x = clampf(start.x, area.position.x + 8.0, area.end.x - 8.0)
	var before := scroll.scroll_vertical
	var bar := scroll.get_v_scroll_bar()
	var room := int(bar.max_value - bar.page) - before  # the list cannot move further than this
	var want := mini(int(dy), room)
	await _drag(start, Vector2(0, -dy), 12, scroll)
	var moved := _scroll_at_lift - before
	check(want <= 10 or (moved >= int(want * 0.85) and moved <= int(want * 1.15) + 2), "%s: dragging %d px should scroll about %d px, scrolled %d" % [label, int(dy), want, moved])
	check(scroll.scroll_vertical >= _scroll_at_lift, "%s: the list keeps going forward after the lift, never back" % label)
	scroll.scroll_vertical = before  # back to the top for the next case
	if scroll is DragScroll:
		(scroll as DragScroll)._coast = 0.0
	await _frames(2)


func _scroll_of(screen: Node) -> ScrollContainer:
	for n in _all(screen):
		if n is ScrollContainer:
			return n
	return null


func _run() -> void:
	var packs: PackScreens = main.packs
	var st := SaveData.pack_state()
	# ---- Treasury ----
	packs.show_treasury()
	await _frames(6)
	var sc := _scroll_of(main.screen)
	check(sc != null and sc.get_v_scroll_bar().max_value > sc.get_v_scroll_bar().page + 20.0, "Treasury has something to scroll")
	var chests_before := Packs.count(st, "crate")
	await _scroll_case("Treasury, from a chest row", sc, _first(sc, func(n): return n is PanelContainer))
	await _scroll_case("Treasury, from a chest icon", sc, _first(sc, func(n): return n is ChestView))
	await _scroll_case("Treasury, from the Open button", sc, _first(sc, func(n): return n is Button and (n as Button).text == "Open"))
	await _scroll_case("Treasury, from the Buy button", sc, _first(sc, func(n): return n is Button and (n as Button).text.begins_with("Buy")))
	await _scroll_case("Treasury, from the Odds link", sc, _first(sc, func(n): return n is Button and (n as Button).text == "Odds"))
	await _scroll_case("Treasury, from the edge", sc, null if sc == null else sc)
	check(Packs.count(st, "crate") == chests_before and (st["pending"] as Array).is_empty() and int(st["doubloons"]) == 5000, "Treasury: dragging over buttons opened or bought nothing")
	# A plain tap still presses the button (and a drag just before did not leave it half pressed).
	var buy_crate := _first(sc, func(n): return n is Button and (n as Button).text == "Buy 200")
	await _tap(buy_crate)
	check(Packs.count(st, "crate") == chests_before + 1 and int(st["doubloons"]) == 5000 - 200, "Treasury: a tap on Buy still buys (crates %d, gold %d)" % [Packs.count(st, "crate"), int(st["doubloons"])])
	st["doubloons"] = 5000
	Packs.grant(st, "crate", -1)
	# ---- Cargo Hold ----
	packs.show_cargo()
	await _frames(6)
	sc = _scroll_of(main.screen)
	await _scroll_case("Cargo Hold, from a card", sc, _first(sc, func(n): return n is CardView))
	await _scroll_case("Cargo Hold, from a progress bar", sc, _first(sc, func(n): return n is Control and n.get_class() == "Control" and (n as Control).custom_minimum_size.y == 24.0))
	await _scroll_case("Cargo Hold, from the edge", sc, sc)
	check(packs._detail == null, "Cargo Hold: dragging over a card did not open it")
	await _tap(_first(sc, func(n): return n is CardView))
	check(packs._detail != null, "Cargo Hold: a tap on a card opens its detail")
	packs._close_detail()
	await _frames(2)
	# A flick leaves the list coasting; a tap during that only stops it and does not press the card under the finger.
	var card_ctl := _first(sc, func(n): return n is CardView)
	var flick_from := card_ctl.get_global_rect().get_center() + Vector2(0, 120)
	await _drag(flick_from, Vector2(0, -90), 3)
	# A card whose middle is inside the list (its height depends on what sits above it).
	await _tap(_first(sc, func(n): return n is CardView and sc.get_global_rect().grow(-40.0).has_point((n as CardView).get_global_rect().get_center())))
	check(packs._detail == null, "Cargo Hold: a tap while the list coasts only stops it")
	sc.scroll_vertical = 0
	await _frames(40)
	await _tap(_first(sc, func(n): return n is CardView))
	check(packs._detail != null, "Cargo Hold: once it has stopped, a tap opens a card again")
	packs._close_detail()
	await _frames(2)
	# ---- Port Market ----
	packs.show_market()
	await _frames(6)
	sc = _scroll_of(main.screen)
	await _scroll_case("Port Market, from a row", sc, _first(sc, func(n): return n is PanelContainer))
	await _scroll_case("Port Market, from a Buy button", sc, _first(sc, func(n): return n is Button and (n as Button).text.begins_with("Buy")))
	check(int(st["pearls"]) == 900, "Port Market: dragging over Buy bought nothing")
	await _tap(_first(sc, func(n): return n is Button and (n as Button).text.begins_with("Buy") and not (n as Button).disabled))
	check(int(st["pearls"]) < 900, "Port Market: a tap on Buy still buys")
	# ---- How to play ----
	main.show_howto()
	await _frames(6)
	sc = _scroll_of(main.screen)
	await _scroll_case("How to play, from text", sc, _first(sc, func(n): return n is Label))
	await _scroll_case("How to play, from a step picture", sc, _first(sc, func(n): return n is HowtoArt))
	# ---- Treasure map ----
	main.show_map(20)
	await _frames(8)
	var ms: ScrollContainer = main.map_scroll
	var area := ms.get_global_rect()
	var mid := area.get_center()
	var before := ms.scroll_vertical
	await _drag(mid, Vector2(0, 260))
	check(abs(ms.scroll_vertical - before) >= 180, "Map: dragging 260 px scrolled %d px" % abs(ms.scroll_vertical - before))
	# ---- Options: how to play ----
	main.show_menu()
	await _frames(4)
	main._open_options()
	await _frames(3)
	main._options_show("howto")
	await _frames(6)
	var opt_scroll: ScrollContainer = null
	for n in _all(main.options_layer):
		if n is ScrollContainer:
			opt_scroll = n
	check(opt_scroll != null, "Options how-to has a scroll")
	if opt_scroll != null:
		await _scroll_case("Options how-to, from text", opt_scroll, _first(opt_scroll, func(n): return n is Label))
		await _scroll_case("Options how-to, from a step picture", opt_scroll, _first(opt_scroll, func(n): return n is HowtoArt))
