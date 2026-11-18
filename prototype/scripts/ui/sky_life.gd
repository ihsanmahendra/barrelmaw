class_name SkyLife
extends Control
## Extras for the menu sky: gulls gliding across, glints on the water, and (at night) stars and a moon.
## All drawn in code over the beach picture. Positions scale with the screen height (designed for 960).

var night: bool = false
var birds: bool = true  # gulls gliding across (off in night stages)
var _gulls: Array = []
var _since: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in 4:
		_gulls.append({"x": rng.randf_range(-100.0, 540.0), "y": rng.randf_range(90.0, 330.0), "speed": rng.randf_range(24.0, 46.0),
			"size": rng.randf_range(0.8, 1.25), "phase": rng.randf() * TAU, "bob": rng.randf_range(4.0, 10.0)})


func _process(delta: float) -> void:
	for g in _gulls:
		g["x"] += g["speed"] * delta
		if g["x"] > size.x + 60.0:
			g["x"] = -60.0
	_since += delta
	if _since >= 1.0 / 30.0:
		_since = 0.0
		queue_redraw()


func _draw() -> void:
	var t := float(Time.get_ticks_msec()) / 1000.0
	var k := size.y / 960.0
	if night:
		_night_sky(t, k)
	var ink := Color(0.12, 0.12, 0.18, 0.85) if not night else Color(0.85, 0.88, 0.98, 0.8)
	for g in _gulls:
		if not birds:
			break
		var flap := sin(t * 5.0 + float(g["phase"]))
		var p := Vector2(float(g["x"]), float(g["y"]) * k + sin(t * 0.8 + float(g["phase"])) * float(g["bob"]))
		var s: float = float(g["size"]) * 16.0 * k
		# A bird as two curved wings that flap up and down.
		var tip := Vector2(s, -s * (0.25 + 0.55 * flap))
		draw_polyline(PackedVector2Array([p + Vector2(-s, tip.y), p + Vector2(-s * 0.5, -s * 0.3 * (0.4 + flap * 0.4)), p]), ink, 2.6)
		draw_polyline(PackedVector2Array([p, p + Vector2(s * 0.5, -s * 0.3 * (0.4 + flap * 0.4)), p + tip]), ink, 2.6)
	# Glints on the water: small white dashes that fade in and out.
	for i in 26:
		var gx := fposmod(float(i) * 83.7 + t * 6.0, size.x)
		var gy := (500.0 + fposmod(float(i) * 47.3, 110.0)) * k
		var a := 0.5 + 0.5 * sin(t * 2.2 + float(i) * 1.9)
		var gl := (7.0 + fposmod(float(i) * 3.1, 9.0)) * k
		draw_line(Vector2(gx, gy), Vector2(gx + gl, gy), Color(1, 1, 1, 0.55 * a), 2.0)


func _night_sky(t: float, k: float) -> void:
	for i in 40:
		var sx := fposmod(float(i) * 97.3, size.x)
		var sy := fposmod(float(i) * 53.1, 330.0) * k + 6.0
		var tw := 0.4 + 0.6 * (0.5 + 0.5 * sin(t * 2.0 + float(i)))
		draw_circle(Vector2(sx, sy), 1.4 + float(i % 3) * 0.6, Color(1, 1, 0.9, tw))
	var m := Vector2(size.x * 0.82, 190.0 * k)
	draw_circle(m, 44.0 * k, Color(1.0, 0.98, 0.85, 0.18))
	draw_circle(m, 30.0 * k, Color("f6f0d8"))
	draw_circle(m + Vector2(-9.0, -7.0) * k, 6.0 * k, Color(0.82, 0.8, 0.7, 0.8))  # a couple of craters
	draw_circle(m + Vector2(8.0, 9.0) * k, 4.0 * k, Color(0.82, 0.8, 0.7, 0.8))
