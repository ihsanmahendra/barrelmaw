class_name PicturePreview
extends Control
## Small preview of a stage's picture, drawn as colored rounded squares.

var rows: Array = []
var _sb := StyleBoxFlat.new()


func set_picture(p_rows: Array) -> void:
	rows = p_rows
	queue_redraw()


func _draw() -> void:
	if rows.is_empty():
		return
	var h := rows.size()
	var w := 0
	for r in rows:
		w = maxi(w, String(r).length())
	var cs := minf(size.x / w, size.y / h)
	var origin := (size - Vector2(w, h) * cs) / 2.0
	# Wooden backing.
	_sb.bg_color = Color(0.25, 0.16, 0.1, 0.92)
	_sb.set_corner_radius_all(14)
	_sb.set_border_width_all(4)
	_sb.border_color = Color("8a5a30")
	draw_style_box(_sb, Rect2(origin, Vector2(w, h) * cs).grow(8.0))
	_sb.set_border_width_all(0)
	_sb.set_corner_radius_all(int(cs * 0.28))
	for y in h:
		for x in String(rows[y]).length():
			var ch := String(rows[y])[x]
			if ch == ".":
				continue
			_sb.bg_color = GameData.color_of(ch)
			draw_style_box(_sb, Rect2(origin + Vector2(x, y) * cs, Vector2(cs, cs)).grow(-1.0))
