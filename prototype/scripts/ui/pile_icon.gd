class_name PileIcon
extends Control
## A little stack of cards with a count badge: the draw pile (blue backs) or the discard pile.

var caption: String = ""
var count: int = 0
var back_color: Color = Color("3a6ea5")
var _sb := StyleBoxFlat.new()


func set_count(n: int) -> void:
	count = n
	queue_redraw()


func _draw() -> void:
	var layers := clampi(ceili(count / 4.0), 1, 3) if count > 0 else 1
	for i in layers:
		var off := Vector2(i * 3.0, -i * 3.0)
		_sb.bg_color = back_color if count > 0 else back_color.darkened(0.5)
		_sb.set_corner_radius_all(7)
		_sb.set_border_width_all(3)
		_sb.border_color = UiKit.CREAM if count > 0 else Color(0.7, 0.65, 0.55)
		_sb.shadow_color = Color(0, 0, 0, 0.3)
		_sb.shadow_size = 3
		var r := Rect2(Vector2(10, 6) + off, Vector2(40, 30))
		draw_style_box(_sb, r)
		if i == layers - 1:
			var c := r.get_center()
			var d := PackedVector2Array([c + Vector2(0, -8), c + Vector2(8, 0), c + Vector2(0, 8), c + Vector2(-8, 0)])
			draw_colored_polygon(d, Color(1, 1, 1, 0.5))
	var font := UiKit.bold_font()
	var badge := Vector2(size.x - 16.0, 22.0)
	draw_circle(badge, 14.0, UiKit.WOOD_DARK)
	draw_arc(badge, 14.0, 0.0, TAU, 20, UiKit.GOLD, 2.5)
	var txt := str(count)
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(font, badge + Vector2(-tw / 2.0, 6.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UiKit.CREAM)
	var cw := ThemeDB.fallback_font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var cp := Vector2((size.x - cw) / 2.0, size.y - 3.0)
	draw_string_outline(ThemeDB.fallback_font, cp, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 5, Color(0.1, 0.06, 0.03, 0.9))
	draw_string(ThemeDB.fallback_font, cp, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiKit.CREAM)
