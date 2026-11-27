class_name LastShotOffer
extends Control
## "So close!": offered over the battle screen when a stage is lost with few barrels left
## (design/gdd/last-shot.md). Emits taken or declined; the screen that shows it does the rest.

signal taken
signal declined

var _m: Control  # the Main screen, for its label and button helpers


func _init(main: Control, battle: Battle, uses_left: int) -> void:
	_m = main
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.custom_minimum_size = Vector2(460, 0)
	holder.add_child(column)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.parchment_style())
	column.add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	panel.add_child(inner)
	inner.add_child(_m._label("So close!", 40, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true, false))
	inner.add_child(_m._label("Out of cannonballs", 18, Color("8a5a30"), HORIZONTAL_ALIGNMENT_CENTER, false, false))
	var left: Array = _remaining(battle)
	inner.add_child(_picture(88.0, func(c: Control) -> void: _draw_barrels(c, left)))
	inner.add_child(_m._label("%d barrel%s left" % [left.size(), "" if left.size() == 1 else "s"], 22, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true, false))
	var ball := _picture(112.0, func(c: Control) -> void: _draw_wild_ball(c, Battle.LAST_SHOT_HITS))
	inner.add_child(ball)
	var spin := Timer.new()  # the wild colors rotate slowly
	spin.wait_time = 0.05
	spin.autostart = true
	spin.timeout.connect(ball.queue_redraw)
	ball.add_child(spin)
	inner.add_child(_m._label("One wild cannonball. Hits any color.", 18, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, false, false))
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.2, 0.12, 0.07, 0.92), Color("a8743f"), 3, 14))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	var note: Label = _m._label("A win now earns", 17, UiKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER, true, false)
	note.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(note)
	var stars := StarsView.new()
	stars.set_value(1, 13.0)
	stars.custom_minimum_size = Vector2(13.0 * 7.2, 30.0)  # the three stars span 7 radii
	row.add_child(stars)
	plate.add_child(row)
	inner.add_child(plate)

	var take: Button = _m._button("Take the shot", func() -> void: taken.emit())
	take.custom_minimum_size = Vector2(0, 72)
	column.add_child(take)
	var give_up: Button = _m._button("Give up", func() -> void: declined.emit(), _m.WOOD)
	give_up.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	give_up.custom_minimum_size = Vector2(240, 52)
	column.add_child(give_up)
	var free := PanelContainer.new()
	free.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	free.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.2, 0.12, 0.07, 0.92), Color("e0a020"), 2, 12))
	var free_label: Label = _m._label("%d free shot%s today" % [uses_left, "" if uses_left == 1 else "s"], 15, UiKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER, true, false)
	free_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	free.add_child(free_label)
	column.add_child(free)

	modulate.a = 0.0
	column.pivot_offset = Vector2(230, 300)
	column.scale = Vector2(0.85, 0.85)
	ready.connect(func() -> void:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "modulate:a", 1.0, 0.15)
		tw.tween_property(column, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))


## The barrels still standing, as [color letter, special kind].
func _remaining(battle: Battle) -> Array:
	var out: Array = []
	var b := battle.board
	for y in b.h:
		for x in b.w:
			if b.get_c(x, y) != "":
				out.append([b.get_c(x, y), b.get_special(x, y)])
	return out


func _picture(height: float, paint: Callable) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(paint.bind(c))
	return c


func _draw_barrels(c: Control, left: Array) -> void:
	var w := 62.0
	var start := (c.size.x - w * left.size()) / 2.0 + w / 2.0
	for i in left.size():
		var at := Vector2(start + w * i, c.size.y / 2.0)
		PirateArt.draw_barrel(c, at, 56.0, 70.0, GameData.color_of(left[i][0]))
		if str(left[i][1]) != "":
			SpecialArt.draw_special(c, at, 58.0, str(left[i][1]), 2, 0.0)


func _draw_wild_ball(c: Control, hits: int) -> void:
	var mid := c.size / 2.0
	var r := 50.0
	var turn := float(Time.get_ticks_msec()) / 2400.0
	var colors := [Color("ef476f"), Color("ffd166"), Color("06d6a0"), Color("4cc9f0"), Color("9b5de5")]
	for k in colors.size():
		var from := turn + TAU * k / colors.size()
		var pts := PackedVector2Array([mid])
		for i in 9:
			var a := from + TAU / colors.size() * i / 8.0
			pts.append(mid + Vector2(cos(a), sin(a)) * r)
		c.draw_colored_polygon(pts, colors[k])
	c.draw_circle(mid + Vector2(-14, -16), 18.0, Color(1, 1, 1, 0.35), true, -1.0, true)
	c.draw_arc(mid, r, 0.0, TAU, 48, Color(1, 1, 1, 0.95), 4.0, true)
	var font := UiKit.bold_font()
	var text := str(hits)
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x
	var at := mid + Vector2(-tw / 2.0, 16.0)
	c.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, 10, Color(0.1, 0.07, 0.05, 0.85))
	c.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color.WHITE)
