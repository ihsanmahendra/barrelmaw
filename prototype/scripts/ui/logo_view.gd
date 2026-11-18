class_name LogoView
extends Control
## The game logo: a wooden sign hanging from two ropes, with gold lettering and cannonball rivets.

const TITLE: String = "BARRELMAW"


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var t := float(Time.get_ticks_msec()) / 1000.0
	var sway := sin(t * 1.4) * 0.012
	var sign_rect := Rect2(Vector2(size.x * 0.06, 34.0), Vector2(size.x * 0.88, size.y - 46.0))
	var pivot := Vector2(size.x / 2.0, 0.0)
	draw_set_transform(pivot, sway, Vector2.ONE)
	var local := Rect2(sign_rect.position - pivot, sign_rect.size)
	# Ropes.
	for fx in [0.16, 0.84]:
		var top := Vector2((fx - 0.5) * size.x * 0.88, -4.0)
		var bottom := Vector2(local.position.x + local.size.x * ((fx - 0.06) / 0.88), local.position.y + 6.0)
		draw_line(top, bottom, Color("8a6a3a"), 6.0)
		draw_line(top + Vector2(-1, 0), bottom + Vector2(-1, 0), Color("c9a468"), 2.0)
	# Sign body with plank seams.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("7a5230")
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(5)
	sb.border_color = Color("3a261a")
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 5)
	draw_style_box(sb, local)
	for i in 1:
		var y := local.position.y + local.size.y * 0.5
		draw_line(Vector2(local.position.x + 8, y), Vector2(local.end.x - 8, y), Color(0.2, 0.12, 0.07, 0.55), 3.0)
	for corner in [Vector2(0.06, 0.2), Vector2(0.94, 0.2), Vector2(0.06, 0.8), Vector2(0.94, 0.8)]:
		var c: Vector2 = local.position + local.size * (corner as Vector2)
		draw_circle(c, 6.0, Color("2a1a10"))
		draw_circle(c + Vector2(-1.5, -1.5), 2.5, Color("a8a8b8"))
	# Lettering.
	var font := UiKit.bold_font()
	var fs := int(local.size.y * 0.52)
	var tw := font.get_string_size(TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if tw > local.size.x - 40.0:
		fs = int(float(fs) * (local.size.x - 40.0) / tw)
		tw = font.get_string_size(TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(local.position.x + (local.size.x - tw) / 2.0, local.position.y + local.size.y * 0.66)
	draw_string_outline(font, pos + Vector2(0, 3), TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 14, Color(0.1, 0.06, 0.03, 0.95))
	draw_string(font, pos, TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiKit.GOLD)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
