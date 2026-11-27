class_name BossBar
extends Control
## The bar under the HUD on a boss stage: the rule's name and how many shots until it strikes again
## (design/gdd/boss-rules.md). Pulses when the next shot brings the strike.

var rule: String = "ghost"
var title: String = ""
var done: int = 0  # shots fired since the last strike (0 to 2)
var striking: bool = false


func _init(p_rule: String, p_title: String) -> void:
	rule = p_rule
	title = p_title
	custom_minimum_size = Vector2(0, 42)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_state(shots_fired: int, p_striking: bool) -> void:
	done = shots_fired % Battle.STRIKE_EVERY
	striking = p_striking
	set_process(not striking and done == Battle.STRIKE_EVERY - 1)
	queue_redraw()


func words() -> String:
	if striking:
		return "strikes now"
	var left := Battle.STRIKE_EVERY - done
	return "strikes in %d shot%s" % [left, "" if left == 1 else "s"]


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var ink: Color = FeatureArt.BOSS_COLORS[rule]["light"]
	var plate: Color = FeatureArt.BOSS_COLORS[rule]["dark"]
	var warn := not striking and done == Battle.STRIKE_EVERY - 1
	var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / 170.0) if warn else 0.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = plate.lightened(0.12 * pulse)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(3)
	sb.border_color = ink.darkened(0.25).lerp(Color.WHITE, pulse * 0.7)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	var font := UiKit.bold_font()
	var y := size.y / 2.0 + 6.0
	draw_string(font, Vector2(14, y), title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, ink)
	var dots := Battle.STRIKE_EVERY
	var filled := dots if striking else done
	var x := size.x - 14.0 - dots * 20.0
	for k in dots:
		var at := Vector2(x + k * 20.0 + 10.0, size.y / 2.0)
		if k < filled:
			draw_circle(at, 7.0, ink, true, -1.0, true)
		else:
			draw_arc(at, 6.5, 0.0, TAU, 20, ink, 2.0, true)
	var text := words()
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(font, Vector2(x - tw - 8.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
