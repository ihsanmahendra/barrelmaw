extends SceneTree
## Injects wheel and touch-drag input into the treasure map and prints how far it scrolls.
## godot --path prototype --script res://tests/map_scroll_test.gd   (needs a window, not --headless)

var main: Control
var step: int = 0


func _initialize() -> void:
	SaveData.path = "user://debug_save.cfg"
	SaveData.reset()
	SaveData.tutorial_done = true
	for k in 8:
		SaveData.record(k, 2)
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	step += 1
	if step == 5:
		main.show_map()
	if step == 15:
		print("start scroll: ", main.map_scroll.scroll_vertical, " max: ", main.map_scroll.get_v_scroll_bar().max_value, " page: ", main.map_scroll.get_v_scroll_bar().page)
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_WHEEL_UP
		e.pressed = true
		e.position = Vector2(270, 500)
		e.global_position = e.position
		Input.parse_input_event(e)
	if step == 25:
		print("after wheel up: ", main.map_scroll.scroll_vertical)
		var t := InputEventScreenTouch.new()
		t.index = 0
		t.pressed = true
		t.position = Vector2(270, 700)
		Input.parse_input_event(t)
	if step >= 26 and step <= 34:
		var d := InputEventScreenDrag.new()
		d.index = 0
		d.position = Vector2(270, 700.0 + float(step - 25) * 30.0)
		d.relative = Vector2(0, 30)
		Input.parse_input_event(d)
	if step == 36:
		var t2 := InputEventScreenTouch.new()
		t2.index = 0
		t2.pressed = false
		t2.position = Vector2(270, 970)
		Input.parse_input_event(t2)
	if step == 50:
		print("after touch drag down 270px: ", main.map_scroll.scroll_vertical)
		main.map_scroll.scroll_vertical = int(main.map_view.node_pos(7).y - 300.0)
	if step == 56:
		var local: Vector2 = main.map_view.node_pos(7) - Vector2(0, main.map_scroll.scroll_vertical)
		var screen_pos: Vector2 = main.map_scroll.global_position + local
		print("tap stage 8 at ", screen_pos)
		for pressed in [true, false]:
			var m := InputEventMouseButton.new()
			m.button_index = MOUSE_BUTTON_LEFT
			m.pressed = pressed
			m.position = screen_pos
			m.global_position = screen_pos
			Input.parse_input_event(m)
	if step == 70:
		print("popup opened after tap: ", main.popup != null)
		quit(0)
	return false
