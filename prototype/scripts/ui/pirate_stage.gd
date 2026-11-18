class_name PirateStage
extends Control
## Animated scene for the menu: the pirate stands on the ship's deck and fires a cannonball high over
## the sea. It shrinks as it flies far away and lands as a small splash near the horizon.

const BARREL_COLORS: Array = ["ef476f", "4cc9f0", "ffd166", "06d6a0", "9b5de5"]
const FLIGHT_TIME: float = 1.3
const RESPAWN_DELAY: float = 1.5

## Emitted when the player taps the pirate and he fires.
signal tapped

## Global point the ship rolls about; set by the screen so this scene rocks with the deck.
var ship_pivot: Vector2 = Vector2(270.0, 720.0)
var _next_fire: float = 1.4
var _recoil: float = 0.0
var _shout: float = 0.0
var _shout_text: String = "FIRE!"
var _cheer: float = 0.0
var _cheer_text: String = "HA HA!"
var _smoke: Array = []
var _balls: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


## Tapping the pirate makes him fire (only one cannonball in the air at a time).
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _balls.is_empty():
		_next_fire = _now() + 3.0
		_fire(_now())
		tapped.emit()


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func _scale_units() -> float:
	return clampf(size.y / 150.0, 0.8, 2.4)


func _origin() -> Vector2:
	return Vector2(size.x * 0.34, size.y - 8.0)


func _muzzle() -> Vector2:
	return PirateArt.lean_transform(_origin(), _now()) * PirateArt.muzzle(_origin(), _scale_units(), _recoil)


func _process(delta: float) -> void:
	var t := _now()
	if t > _next_fire:
		_next_fire = t + 3.0
		_fire(t)
	_recoil = maxf(0.0, _recoil - delta * 3.5)
	_shout = maxf(0.0, _shout - delta * 1.5)
	_cheer = maxf(0.0, _cheer - delta * 0.8)
	var still: Array = []
	for b in _balls:
		b["t"] += delta
		if b["t"] >= FLIGHT_TIME:
			_land(b, t)
		else:
			still.append(b)
	_balls = still
	_smoke = _advance(_smoke, delta, 0.0)
	queue_redraw()


func _advance(list: Array, delta: float, gravity: float) -> Array:
	var alive: Array = []
	for c in list:
		c["t"] += delta
		if c["t"] < c["life"]:
			c["vel"].y += gravity * delta
			c["pos"] += c["vel"] * delta
			alive.append(c)
	return alive


func _fire(_t: float) -> void:
	var m := _muzzle()
	_recoil = 1.0
	_shout = 1.0
	_shout_text = ["FIRE!", "ARRR!", "BOOM!", "YARR!"][randi() % 4]
	# Far target: well to the right of the screen edge and up near the horizon.
	var target := Vector2(size.x * 0.97, m.y - size.y * 0.30)
	_balls.append({"from": m, "to": target, "t": 0.0, "color": Color.html("#" + BARREL_COLORS[randi() % BARREL_COLORS.size()])})
	for i in 7:
		_smoke.append({"pos": m, "vel": Vector2(randf_range(15, 60), randf_range(-70, -20)), "t": 0.0, "life": randf_range(0.8, 1.4), "size": randf_range(10.0, 20.0)})


func _land(b: Dictionary, _t: float) -> void:
	_cheer = 1.0
	_cheer_text = ["HA HA!", "NICE!", "HA HA HA!"][randi() % 3]


func _draw() -> void:
	var t := _now()
	var u := _scale_units()
	var rock := ShipMotion.transform(ship_pivot - global_position, t)
	draw_set_transform_matrix(rock)
	PirateArt.draw_pirate(self, _origin(), u, t, _recoil, rock, _shout > 0.0, _cheer > 0.0)
	draw_set_transform_matrix(rock)
	if _cheer > 0.0:
		PirateArt.draw_shout_bubble(self, _origin(), u, _cheer, _cheer_text, rock, Color(0.1, 0.5, 0.28))
	elif _shout > 0.0:
		PirateArt.draw_shout_bubble(self, _origin(), u, _shout, _shout_text, rock)
	# The cannonball flies in a high arc, shrinking and fading as it gets far away.
	for b in _balls:
		var k: float = b["t"] / FLIGHT_TIME
		var pos: Vector2 = (b["from"] as Vector2).lerp(b["to"], k) + Vector2(0, -34.0 * u * sin(PI * k))
		var shrink := 1.0 - 0.8 * k
		var col: Color = b["color"]
		col.a = 1.0 - 0.6 * k * k
		PirateArt.draw_cannonball(self, pos, 12.0 * u * 0.9 * shrink, col)
	var m := _muzzle()
	if _recoil > 0.7:
		draw_circle(m, 26.0 * _recoil, Color(1.0, 0.85, 0.35, 0.85))
	for c in _smoke:
		var k2: float = float(c["t"]) / float(c["life"])
		draw_circle(c["pos"], float(c["size"]) * (0.6 + 0.9 * k2), Color(0.9, 0.9, 0.94, 0.6 * (1.0 - k2)))
	draw_set_transform_matrix(Transform2D.IDENTITY)
