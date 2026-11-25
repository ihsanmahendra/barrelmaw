class_name BurstFx
extends Control
## A short burst of light: expanding rings and a spray of sparks in one color. It removes itself when done.
## Used when a card flips in a chest, when a card merges and for the Transcended reveal.

var color: Color = Color.WHITE
var power: float = 1.0  # 0.5 small, 1 normal, 2 big
var aurora: bool = false  # cycle teal, violet and gold (Transcended)
var life: float = 0.9
var _t: float = 0.0
var _sparks: Array = []


func _init(p_color: Color = Color.WHITE, p_power: float = 1.0, p_aurora: bool = false) -> void:
	color = p_color
	power = p_power
	aurora = p_aurora
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in int(14.0 * power):
		_sparks.append({"a": rng.randf() * TAU, "speed": rng.randf_range(0.5, 1.0), "size": rng.randf_range(2.0, 5.0), "hue": rng.randf()})
	custom_minimum_size = Vector2(260, 260) * power
	size = custom_minimum_size
	pivot_offset = size / 2.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= life:
		queue_free()


func _col(h: float, a: float) -> Color:
	var base := UiKit.aurora(_t * 2.0 + h * 5.0) if aurora else color
	return Color(base.r, base.g, base.b, a)


func _draw() -> void:
	var c := size / 2.0
	var k := clampf(_t / life, 0.0, 1.0)
	var ease_out := 1.0 - (1.0 - k) * (1.0 - k)
	var fade := 1.0 - k
	var r_max := size.x * 0.5
	draw_circle(c, r_max * 0.38 * (1.0 - k), _col(0.0, 0.22 * fade * fade))
	draw_arc(c, r_max * 0.15 + r_max * 0.85 * ease_out, 0.0, TAU, 40, _col(0.3, 0.8 * fade), maxf(1.0, 9.0 * fade * power))
	if power >= 1.0:
		draw_arc(c, r_max * 0.1 + r_max * 0.6 * ease_out, 0.0, TAU, 32, _col(0.6, 0.6 * fade), maxf(1.0, 5.0 * fade))
	for s in _sparks:
		var d := r_max * 0.25 + r_max * 0.8 * ease_out * float(s["speed"])
		var p := c + Vector2(cos(float(s["a"])), sin(float(s["a"]))) * d
		draw_circle(p, float(s["size"]) * (1.0 - k * 0.7), _col(float(s["hue"]), fade))
