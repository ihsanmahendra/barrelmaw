class_name SpecialsRow
extends Control
## A row of special-barrel icons with their counts ("bomb x2, iron x3 ..."), shown in the stage pop-up.

var counts: Dictionary = {}


func set_counts(d: Dictionary) -> void:
	counts = d
	custom_minimum_size = Vector2(0, 52)
	queue_redraw()


func _draw() -> void:
	var kinds: Array = []
	for k in Board.SPECIALS:
		if int(counts.get(k, 0)) > 0:
			kinds.append(k)
	if kinds.is_empty():
		return
	var cell := 78.0
	var start := (size.x - cell * kinds.size()) / 2.0
	var font := UiKit.bold_font()
	for i in kinds.size():
		var kind: String = kinds[i]
		var c := Vector2(start + i * cell + 20.0, 26.0)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.25, 0.16, 0.1, 0.9)
		sb.set_corner_radius_all(12)
		sb.set_border_width_all(2)
		sb.border_color = Color("6bd16b") if SpecialArt.is_good(kind) else Color("d65a6b")
		draw_style_box(sb, Rect2(c - Vector2(20, 22), Vector2(cell - 6.0, 44)))
		SpecialArt.draw_special(self, c, 34.0, kind, 2, float(Time.get_ticks_msec()) / 1000.0)
		var txt := "x%d" % int(counts[kind])
		draw_string_outline(font, c + Vector2(24, 7), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color(0, 0, 0, 0.7))
		draw_string(font, c + Vector2(24, 7), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiKit.CREAM)
