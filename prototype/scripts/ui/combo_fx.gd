class_name ComboFx
extends Control
## The shout over the board after a big shot (design/gdd/combo-feedback.md): "Broadside!", "Full broadside!"
## or a "PLUNDER!" stamp, with the number of barrels. Only for show: it takes no input and removes itself.

const TIERS: Array = [15, 27, 40]  # barrels removed by one press of FIRE for tiers 1, 2 and 3
const SHAKE: Array = [0.0, 4.0, 7.0, 10.0]  # board shake per tier
const TEXT: Array = ["", "Broadside!", "Full broadside!", "PLUNDER!"]

var tier: int = 1
var barrels: int = 0
var hold_at: float = -1.0  # debug screenshots: the animation stops at this time
var _t: float = 0.0
var _life: float = 0.8
var _coins: Array = []  # {pos (0..1), vel, size, spin}


static func tier_of(n: int) -> int:
	for k in range(TIERS.size() - 1, -1, -1):
		if n >= int(TIERS[k]):
			return k + 1
	return 0


func _init(count: int = 15) -> void:
	barrels = count
	tier = maxi(tier_of(count), 1)
	_life = 1.1 if tier == 3 else 0.8
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if tier >= 2:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for i in 16 if tier == 2 else 28:
			var a := rng.randf() * TAU
			_coins.append({"dir": Vector2(cos(a), sin(a) * 0.7), "speed": rng.randf_range(0.25, 0.75),
				"size": rng.randf_range(5.0, 11.0), "spin": rng.randf() * TAU})


func _process(delta: float) -> void:
	_t += delta
	if hold_at >= 0.0:
		_t = minf(_t, hold_at)
	queue_redraw()
	if _t >= _life:
		queue_free()


func _draw() -> void:
	var mid := size / 2.0
	var fade := clampf((_life - _t) / 0.2, 0.0, 1.0)
	var pop := clampf(_t / 0.18, 0.0, 1.0)
	if tier == 3:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45 * fade))
	var reach := minf(size.x, size.y) * 0.9
	for c in _coins:
		var k := clampf(_t / _life, 0.0, 1.0)
		var at: Vector2 = mid + (c["dir"] as Vector2) * reach * float(c["speed"]) * (1.0 - (1.0 - k) * (1.0 - k)) + Vector2(0, 110.0 * k * k)
		var squash := maxf(0.2, absf(cos(float(c["spin"]) + _t * 9.0)))
		draw_set_transform(at, 0.0, Vector2(squash, 1.0))
		draw_circle(Vector2.ZERO, float(c["size"]), Color(1.0, 0.82, 0.25, fade), true, -1.0, true)
		draw_arc(Vector2.ZERO, float(c["size"]), 0.0, TAU, 14, Color(0.55, 0.33, 0.05, fade), 2.0, true)
	var font := UiKit.bold_font()
	var count_text := "%d barrels" % barrels
	if tier == 3:
		_draw_stamp(font, mid, count_text, fade)
		return
	var fs := 44 if tier == 1 else 50
	while font.get_string_size(TEXT[tier], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - 20.0 and fs > 22:
		fs -= 2
	var grow := lerpf(0.5, 1.0, pop) + 0.12 * sin(pop * PI)
	draw_set_transform(mid, deg_to_rad(-6.0), Vector2(grow, grow))
	_centered(font, TEXT[tier], 0.0, fs, Color("fff6dd") if tier == 1 else Color("ffd166"), fade)
	_centered(font, count_text, 42.0, 26, Color("fff6dd"), fade)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A red stamp on paper that slams down, like the win stamp.
func _draw_stamp(font: Font, mid: Vector2, count_text: String, fade: float) -> void:
	var slam := clampf(_t / 0.25, 0.0, 1.0)
	var k := lerpf(2.2, 1.0, slam * slam)
	var width := minf(360.0, size.x - 16.0)
	draw_set_transform(mid, deg_to_rad(-9.0), Vector2(k, k))
	var box := Rect2(Vector2(-width / 2.0, -62.0), Vector2(width, 124.0))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.98, 0.94, 0.84, fade)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(7)
	sb.border_color = Color(0.82, 0.13, 0.2, fade)
	sb.shadow_color = Color(0, 0, 0, 0.35 * fade)
	sb.shadow_size = 10
	draw_style_box(sb, box)
	var fs := 60
	while font.get_string_size(TEXT[3], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width - 30.0 and fs > 24:
		fs -= 2
	var red := Color(0.82, 0.13, 0.2, fade)
	var tw := font.get_string_size(TEXT[3], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(-tw / 2.0, 14.0), TEXT[3], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, red)
	var cw := font.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	draw_string(font, Vector2(-cw / 2.0, 46.0), count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, red)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _centered(font: Font, text: String, y: float, fs: int, color: Color, fade: float) -> void:
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := Vector2(-tw / 2.0, y)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 12, Color(0.17, 0.09, 0.04, fade))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(color, fade))
