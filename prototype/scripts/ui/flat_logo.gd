class_name FlatLogo
extends Control
## Hand-cut style title burned into a wooden plank: each letter is slightly rotated and shifted, dark
## brown with a pale lip below, over a wavy carved underline.

const TITLE: String = "BARRELMAW"
const NAVY := Color("1f2a3a")
const CORAL := Color("e8694f")
const CREAM := Color("f4e6c8")


func _draw() -> void:
	# Wooden plank behind the lettering, hung from two short ropes.
	var plank := Rect2(Vector2(6.0, size.y * 0.06), Vector2(size.x - 12.0, size.y * 0.88))
	for fx in [0.14, 0.86]:
		draw_line(Vector2(size.x * fx, 0.0), Vector2(size.x * fx, plank.position.y + 10.0), Color("8a6a3a"), 5.0)
		draw_line(Vector2(size.x * fx - 1.0, 0.0), Vector2(size.x * fx - 1.0, plank.position.y + 10.0), Color("c9a468"), 2.0)
	draw_style_box(UiKit.plank_style(Color("c9955a")), plank)
	var font := UiKit.bold_font()
	var fs := 82
	var total := 0.0
	var widths: Array = []
	for ch in TITLE:
		var wch := font.get_string_size(String(ch), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 2.0
		widths.append(wch)
		total += wch
	while total > size.x - 70.0 and fs > 40:
		fs -= 2
		total = 0.0
		widths.clear()
		for ch in TITLE:
			var wch2 := font.get_string_size(String(ch), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 2.0
			widths.append(wch2)
			total += wch2
	var x := (size.x - total) / 2.0
	var base := size.y * 0.62
	for i in TITLE.length():
		var jitter_rot := deg_to_rad(sin(float(i) * 2.3) * 3.2)
		var jitter_y := cos(float(i) * 1.7) * 4.0
		var center := Vector2(x + widths[i] / 2.0, base + jitter_y)
		var glyph := String(TITLE[i])
		var gw: float = font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_set_transform(center, jitter_rot, Vector2.ONE)
		# Burned into the wood: a pale lip below catches the light, the letter is dark brown and slightly
		# see-through so the grain shows, and a deeper core makes it look cut in.
		draw_string(font, Vector2(-gw / 2.0, 4.0), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.9, 0.68, 0.55))
		draw_string(font, Vector2(-gw / 2.0, 0.0), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.24, 0.13, 0.07, 0.88))
		draw_string(font, Vector2(-gw / 2.0 + 1.5, 1.5), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.12, 0.06, 0.03, 0.35))
		x += widths[i]
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Wavy hand-drawn underline.
	var pts := PackedVector2Array()
	var ux := (size.x - total) / 2.0
	var steps := 36
	for i in steps + 1:
		var k := float(i) / float(steps)
		pts.append(Vector2(ux + k * total, size.y * 0.62 + 14.0 + sin(k * TAU * 3.0) * 4.0))
	draw_polyline(PackedVector2Array(Array(pts).map(func(p: Vector2) -> Vector2: return p + Vector2(0, 3.0))), Color(1.0, 0.9, 0.68, 0.5), 4.0)
	draw_polyline(pts, Color(0.24, 0.13, 0.07, 0.88), 4.0)
