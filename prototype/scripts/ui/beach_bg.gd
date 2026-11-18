class_name BeachBackground
extends Control
## Animated beach scene drawn in code: sky, sun, drifting clouds, sea with waves and a small
## ship, palm trees and a sandy shore. Sits behind every screen.

const SHORE_FRACTION: float = 0.56
const SEA_TOP_FRACTION: float = 0.36


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	if _bg_tex == null:
		queue_redraw()  # only the drawn fallback is animated


func _gradient_rect(rect: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(
		PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


const BG_PATH: String = "res://assets/art/beach_bg.jpg"
static var _bg_tex: Texture2D = null
static var _bg_checked: bool = false


func _draw() -> void:
	if not _bg_checked:
		_bg_checked = true
		_bg_tex = load(BG_PATH) if ResourceLoader.exists(BG_PATH) else null
	if _bg_tex != null:
		# Generated art, scaled to cover the whole screen (centered crop).
		var k := maxf(size.x / _bg_tex.get_width(), size.y / _bg_tex.get_height())
		var dest := Vector2(_bg_tex.get_width(), _bg_tex.get_height()) * k
		draw_texture_rect(_bg_tex, Rect2((size - dest) / 2.0, dest), false)
		return
	_draw_procedural()


## Fallback scene drawn in code, used when the generated background is missing.
func _draw_procedural() -> void:
	var t := float(Time.get_ticks_msec()) / 1000.0
	var w := size.x
	var h := size.y
	var sea_top := h * SEA_TOP_FRACTION
	var shore := h * SHORE_FRACTION
	# Sky.
	_gradient_rect(Rect2(0, 0, w, sea_top + 2.0), Color("3fa9e0"), Color("bfe8f6"))
	# Sun with a soft halo.
	var sun := Vector2(w * 0.9, h * 0.27)
	draw_circle(sun, 64.0, Color(1.0, 0.95, 0.6, 0.18))
	draw_circle(sun, 46.0, Color(1.0, 0.93, 0.5, 0.35))
	draw_circle(sun, 32.0, Color("ffe066"))
	# Clouds drifting right.
	for i in 3:
		var cx := fposmod(t * (6.0 + 3.0 * i) + i * w * 0.42, w + 200.0) - 100.0
		_cloud(Vector2(cx, h * (0.06 + 0.07 * i)), 0.8 + 0.3 * i)
	# Sea with a gradient and moving wave lines.
	_gradient_rect(Rect2(0, sea_top, w, shore - sea_top + 6.0), Color("2fb7d6"), Color("147fa6"))
	for r in 5:
		var y := sea_top + 14.0 + r * (shore - sea_top) / 5.5
		var pts := PackedVector2Array()
		var x := 0.0
		while x <= w + 10.0:
			pts.append(Vector2(x, y + sin(x * 0.03 + t * 1.4 + r * 1.7) * 3.0))
			x += 10.0
		draw_polyline(pts, Color(1, 1, 1, 0.22), 2.0)
	_ship(Vector2(fposmod(t * 5.0, w + 160.0) - 80.0, sea_top + 18.0 + sin(t * 1.3) * 2.0))
	# Sand with a wavy shoreline and foam.
	var shore_pts := PackedVector2Array()
	var x2 := 0.0
	while x2 <= w + 10.0:
		shore_pts.append(Vector2(x2, shore + sin(x2 * 0.02 + t * 0.8) * 5.0))
		x2 += 10.0
	var sand := PackedVector2Array(shore_pts)
	sand.append(Vector2(w, h))
	sand.append(Vector2(0, h))
	var sand_colors := PackedColorArray()
	for i in shore_pts.size():
		sand_colors.append(Color("f7e4b0"))
	sand_colors.append(Color("dfb56e"))
	sand_colors.append(Color("dfb56e"))
	draw_polygon(sand, sand_colors)
	draw_polyline(shore_pts, Color(1, 1, 1, 0.85), 5.0)
	var wet := PackedVector2Array()
	for p in shore_pts:
		wet.append(p + Vector2(0, 14.0))
	draw_polyline(wet, Color(0.75, 0.6, 0.35, 0.35), 8.0)
	# Palm trees at both edges and a few shells and starfish.
	_palm(Vector2(w * 0.04, shore + 30.0), h * 0.30, 0.12, t)
	_palm(Vector2(w * 0.97, shore + 24.0), h * 0.27, -0.12, t + 1.3)
	_starfish(Vector2(w * 0.78, h * 0.93), 13.0)
	_starfish(Vector2(w * 0.16, h * 0.96), 9.0)
	draw_circle(Vector2(w * 0.5, h * 0.985), 6.0, Color("f4b6a4"))


func _cloud(pos: Vector2, s: float) -> void:
	var c := Color(1, 1, 1, 0.9)
	draw_circle(pos, 20.0 * s, c)
	draw_circle(pos + Vector2(22, 4) * s, 24.0 * s, c)
	draw_circle(pos + Vector2(46, 6) * s, 18.0 * s, c)
	draw_circle(pos + Vector2(20, 12) * s, 20.0 * s, c)


func _ship(pos: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([pos + Vector2(-22, 0), pos + Vector2(22, 0), pos + Vector2(14, 10), pos + Vector2(-14, 10)]), Color("5a3a22"))
	draw_line(pos + Vector2(0, 0), pos + Vector2(0, -34), Color("3b2a1e"), 3.0)
	draw_colored_polygon(PackedVector2Array([pos + Vector2(2, -32), pos + Vector2(20, -8), pos + Vector2(2, -8)]), Color("f6ead0"))
	draw_colored_polygon(PackedVector2Array([pos + Vector2(-2, -28), pos + Vector2(-16, -8), pos + Vector2(-2, -8)]), Color("e8d9b5"))


func _palm(base: Vector2, height: float, lean: float, t: float) -> void:
	var points: Array = []
	for i in 9:
		var u := float(i) / 8.0
		points.append(base + Vector2(lean * height * u * u, -height * u))
	for i in 8:
		var wid := lerpf(16.0, 8.0, float(i) / 8.0)
		draw_line(points[i], points[i + 1], Color("8a5a30"), wid)
		draw_line(points[i] + Vector2(-wid * 0.25, 0), points[i + 1] + Vector2(-wid * 0.25, 0), Color("a8743f"), wid * 0.25)
	var top: Vector2 = points[8]
	var angles := [-2.9, -2.4, -1.9, -1.2, -0.7, -0.2]
	for k in angles.size():
		var a: float = angles[k] + sin(t * 1.3 + k) * 0.05
		_frond(top, a, height * 0.5)
	draw_circle(top + Vector2(-6, 8), 6.0, Color("6b4423"))
	draw_circle(top + Vector2(6, 9), 6.0, Color("5a3a22"))


func _frond(top: Vector2, angle: float, length: float) -> void:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var dir := Vector2(cos(angle), sin(angle))
	var normal := Vector2(-dir.y, dir.x)
	for j in 9:
		var u := float(j) / 8.0
		var center := top + dir * length * u + Vector2(0, length * 0.55 * u * u)
		var half := length * 0.16 * sin(PI * clampf(u, 0.04, 0.96))
		left.append(center + normal * half)
		right.append(center - normal * half)
	right.reverse()
	left.append_array(right)
	draw_colored_polygon(left, Color("2e9e4a"))
	var mid := PackedVector2Array()
	for j in 9:
		var u2 := float(j) / 8.0
		mid.append(top + dir * length * u2 + Vector2(0, length * 0.55 * u2 * u2))
	draw_polyline(mid, Color("63d17a"), 2.0)


func _starfish(pos: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(pos + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, Color("f48c4a"))
