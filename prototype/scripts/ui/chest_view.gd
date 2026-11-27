class_name ChestView
extends Control
## A chest as a control: set chest_id, then animate open_t (0 to 1) and shake from outside.

var chest_id: String = "crate":
	set(value):
		chest_id = value
		queue_redraw()
var open_t: float = 0.0:
	set(value):
		open_t = value
		queue_redraw()
var shake: float = 0.0:
	set(value):
		shake = value
		queue_redraw()
var animate: bool = true  # keep redrawing for the shimmer; off for small icons in lists
var _time: float = 0.0


func _init(p_chest_id: String = "crate", p_animate: bool = true) -> void:
	chest_id = p_chest_id
	animate = p_animate
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(80, 70)


func _process(delta: float) -> void:
	_time += delta
	if animate:
		queue_redraw()


func _art_width() -> float:
	return minf(size.x, size.y * 1.25) * 0.86


func _art_center() -> Vector2:
	return size / 2.0 + Vector2(0, size.y * 0.04)


## Lowest point of the shut chest and its shadow, in this control's pixels (it can reach past the control).
func art_bottom() -> float:
	return _art_center().y + ChestArt.bottom(_art_width())


func _draw() -> void:
	var off := Vector2(sin(_time * 70.0), cos(_time * 53.0)) * shake
	if not animate and open_t <= 0.0 and shake <= 0.0:
		ChestArt.draw_still(self, _art_center(), _art_width(), chest_id)
	else:
		ChestArt.draw(self, _art_center() + off, _art_width(), chest_id, open_t, _time)
