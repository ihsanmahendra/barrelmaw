class_name StarsView
extends Control
## Row of three stars, filled up to `value`. `reveal` animates them popping in one by one.

var value: int = 0
var star_size: float = 22.0
var _shown: float = 99.0  # how many stars the reveal animation has reached


func set_value(v: int, size_px: float = 22.0) -> void:
	value = v
	star_size = size_px
	custom_minimum_size = Vector2(star_size * 3.0 * 1.25, star_size * 2.2)
	queue_redraw()


## Pops the earned stars in with a short delay between them.
func reveal() -> void:
	_shown = 0.0
	var tw := create_tween()
	tw.tween_property(self, "_shown", float(value) + 0.99, 0.35 * maxf(1.0, float(value)))
	tw.tween_callback(func() -> void: _shown = 99.0)


func _process(_delta: float) -> void:
	if _shown < 98.0:
		queue_redraw()


func _draw() -> void:
	var r := star_size
	var step := r * 2.5
	var start := size.x / 2.0 - step
	for i in 3:
		var c := Vector2(start + i * step, size.y / 2.0)
		var earned := i < value and float(i) < _shown
		if earned:
			var pop := clampf(_shown - float(i), 0.0, 1.0)
			var k := 1.0 + 0.35 * sin(pop * PI) if _shown < 98.0 else 1.0
			UiKit.draw_star(self, c, r * k, UiKit.GOLD, Color("a8651a"))
		else:
			UiKit.draw_star(self, c, r, Color(0.15, 0.1, 0.07, 0.55), Color(0.55, 0.45, 0.3, 0.8))
