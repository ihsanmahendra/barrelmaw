class_name Highlight
extends Control
## Pulsing outline drawn around another control to tell the player where to look or tap.

var target_fn: Callable = Callable():  # returns the Control to outline, or null
	set(value):
		target_fn = value
		set_process(value.is_valid())
		queue_redraw()
var _style := StyleBoxFlat.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(target_fn.is_valid())


func clear() -> void:
	target_fn = Callable()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not target_fn.is_valid():
		return
	var t: Variant = target_fn.call()
	if not (t is Control) or not is_instance_valid(t) or not (t as Control).is_visible_in_tree():
		return
	var rect: Rect2 = (t as Control).get_global_rect()
	var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / 170.0)
	var grow := 3.0 + 4.0 * pulse
	_style.bg_color = Color(1.0, 0.82, 0.4, 0.07 + 0.08 * pulse)
	_style.border_color = Color(1.0, 0.82, 0.4, 0.7 + 0.3 * pulse)
	_style.set_border_width_all(5)
	_style.set_corner_radius_all(22)
	_style.draw(get_canvas_item(), Rect2(rect.position - get_global_rect().position, rect.size).grow(grow))
