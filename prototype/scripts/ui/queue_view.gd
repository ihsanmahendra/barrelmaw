class_name QueueView
extends Control
## The pirate with his cannon, and the row of colored cannonballs waiting to be fired.
## The front cannonball is loaded into the cannon next. Its number is how many barrels it
## smashes, including pending bonuses from cards.

const PIRATE_W: float = 164.0
const TAG_H: float = 20.0

var battle: Battle
## Night stages: a warm lantern stands beside the pirate and lights him and the cannon.
var night: bool = false
## Global point the ship rolls about; set by the screen so this row rocks with the deck.
var ship_pivot: Vector2 = Vector2(270.0, 720.0)
var _recoil: float = 0.0
var _flash: float = 0.0
var _shout: float = 0.0  # the pirate keeps his firing face while this is above zero
var _shout_text: String = "FIRE!"
var _cheer: float = 0.0  # the pirate grins while this is above zero (a big hit landed)
var _cheer_text: String = "HA HA!"
var _load_t: float = -1.0
var _load_color: Color = Color.WHITE
var _smoke: Array = []  # pos, t, life, size
var _leaving: Array = []  # cannonballs removed because their color is gone: color, number, pos, t


func _ready() -> void:
	resized.connect(queue_redraw)


func set_battle(b: Battle) -> void:
	battle = b
	queue_redraw()


func _unit() -> float:
	return clampf(size.y / 128.0, 0.6, 1.2)


func _pirate_origin() -> Vector2:
	return Vector2(58.0, size.y - 6.0)


## Cannon muzzle in this control's local pixels. Cannonballs start here.
func muzzle_local() -> Vector2:
	var t := float(Time.get_ticks_msec()) / 1000.0
	var lean := PirateArt.lean_transform(_pirate_origin(), t)
	return _rock() * lean * PirateArt.muzzle(_pirate_origin(), _unit())


## The current rocking transform in this control's local pixels.
func _rock() -> Transform2D:
	return ShipMotion.transform(ship_pivot - global_position, float(Time.get_ticks_msec()) / 1000.0)


## Shows cannonballs that were removed because no barrel of their color is left: each one puffs away.
func show_removed(balls: Array) -> void:
	var avail := size.y - TAG_H
	var x := PIRATE_W + 8.0
	for i in balls.size():
		var r := avail * 0.27
		_leaving.append({"color": GameData.color_of(balls[i]["color"]), "number": str(balls[i]["ammo"]),
			"pos": Vector2(x + r + i * (r * 2.0 + 8.0), size.y - r - 6.0), "r": r, "t": 0.0})
		for k in 4:
			_smoke.append({"pos": _leaving[-1]["pos"], "vel": Vector2(randf_range(-30, 30), randf_range(-60, -20)), "t": 0.0, "life": randf_range(0.4, 0.8), "size": randf_range(6.0, 12.0)})
	set_process(true)


## Call when a big hit has landed: the pirate grins and laughs for a moment.
func cheer(barrels_smashed: int) -> void:
	_cheer = 1.0
	var words: Array = ["HA HA HA!", "YO HO HO!"] if barrels_smashed >= 12 else ["HA HA!", "NICE!", "GOT 'EM!"]
	_cheer_text = words[randi() % words.size()]


## Call when a shot leaves the cannon: recoil, flash, smoke, and (for the first shot of an
## action) the front cannonball dropping into the cannon.
func kick(color_letter: String, first: bool) -> void:
	_recoil = 1.0
	_flash = 1.0
	_shout = 1.0
	_shout_text = ["FIRE!", "ARRR!", "BOOM!", "YARR!"][randi() % 4]
	var m := muzzle_local()
	for i in 5:
		_smoke.append({"pos": m + Vector2(randf_range(-4, 4), randf_range(-4, 4)), "vel": Vector2(randf_range(10, 40), randf_range(-45, -15)),
			"t": 0.0, "life": randf_range(0.5, 0.9), "size": randf_range(7.0, 13.0)})
	if first:
		_load_t = 0.0
		_load_color = GameData.color_of(color_letter)


func _process(delta: float) -> void:
	_recoil = maxf(0.0, _recoil - delta * 5.0)
	_flash = maxf(0.0, _flash - delta * 9.0)
	_shout = maxf(0.0, _shout - delta * 1.5)
	_cheer = maxf(0.0, _cheer - delta * 0.8)
	if _load_t >= 0.0:
		_load_t += delta / 0.28
		if _load_t >= 1.0:
			_load_t = -1.0
	var alive: Array = []
	for s in _smoke:
		s["t"] += delta
		if s["t"] < s["life"]:
			s["pos"] += s["vel"] * delta
			alive.append(s)
	_smoke = alive
	var still: Array = []
	for l in _leaving:
		l["t"] += delta
		if l["t"] < 0.9:
			still.append(l)
	_leaving = still
	queue_redraw()


func _draw() -> void:
	if battle == null:
		return
	var t := float(Time.get_ticks_msec()) / 1000.0
	var rock := _rock()
	draw_set_transform_matrix(rock)
	var u := _unit()
	var origin := _pirate_origin()
	if night:
		_draw_lantern(origin, u, t)
	PirateArt.draw_pirate(self, origin, u, t, _recoil, rock, _shout > 0.0, _cheer > 0.0)
	draw_set_transform_matrix(rock)  # the pirate drawing may have changed the transform
	if _cheer > 0.0:
		PirateArt.draw_shout_bubble(self, origin, u, _cheer, _cheer_text, rock, Color(0.1, 0.5, 0.28))
	elif _shout > 0.0:
		PirateArt.draw_shout_bubble(self, origin, u, _shout, _shout_text, rock)
	var font := ThemeDB.fallback_font
	var avail := size.y - TAG_H
	var x := PIRATE_W + 8.0
	var shown := 0
	var first_center := Vector2.ZERO
	for i in battle.queue.size():
		var s: Dictionary = battle.queue[i]
		var front := i == 0
		var r := avail * 0.37 if front else avail * 0.27
		if x + r * 2.0 > size.x - 34.0 and not front:
			break
		var center := Vector2(x + r + ShipMotion.slide(t), size.y - r - 6.0)  # balls roll a little on the planks
		if front:
			first_center = center
		var col := GameData.color_of(s["color"])
		if (front and battle.mods["wild"]) or bool(s.get("wild", false)):
			col = Color("f6ead0")  # pale balls hit any color
		var ammo: int = int(s["ammo"])
		if front:
			ammo += int(battle.mods["ammo"])
			if battle.mods["double"]:
				ammo *= 2
			var tag_y := center.y - r - 8.0
			draw_string_outline(font, Vector2(x - 8.0, tag_y), "NEXT", HORIZONTAL_ALIGNMENT_CENTER, r * 2.0 + 16.0, 15, 5, Color(0.1, 0.07, 0.05, 0.8))
			draw_string(font, Vector2(x - 8.0, tag_y), "NEXT", HORIZONTAL_ALIGNMENT_CENTER, r * 2.0 + 16.0, 15, Color("ffd166"))
		PirateArt.draw_cannonball(self, center, r, col, str(ammo), int(r * 0.95))
		x += r * 2.0 + 8.0
		shown += 1
	var more := battle.queue.size() - shown
	if more > 0:
		draw_string_outline(font, Vector2(x, size.y - avail * 0.2), "+%d" % more, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, Color(0.1, 0.07, 0.05, 0.9))
		draw_string(font, Vector2(x, size.y - avail * 0.2), "+%d" % more, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("fff4dc"))
	# The cannonball that was just loaded drops from the front slot into the cannon.
	if _load_t >= 0.0:
		var from := first_center if first_center != Vector2.ZERO else Vector2(PIRATE_W + 40.0, size.y - 40.0)
		var to := PirateArt.loading_point(origin, u)
		var k := _load_t * _load_t
		PirateArt.draw_cannonball(self, from.lerp(to, k), 24.0 * (1.0 - 0.3 * k), _load_color)
	for l in _leaving:
		var k: float = float(l["t"]) / 0.9
		var rr: float = float(l["r"]) * (1.0 - 0.6 * k)
		var pos: Vector2 = (l["pos"] as Vector2) + Vector2(0.0, -34.0 * k)
		PirateArt.draw_cannonball(self, pos, rr, Color(l["color"].r, l["color"].g, l["color"].b, 1.0 - k), l["number"], int(rr * 0.95))
	# Muzzle flash and smoke.
	var m := muzzle_local()
	if _flash > 0.0:
		draw_circle(m, 22.0 * _flash + 6.0, Color(1.0, 0.85, 0.35, 0.85 * _flash))
		draw_circle(m, 11.0 * _flash + 3.0, Color(1.0, 1.0, 0.9, _flash))
	for s in _smoke:
		var k2: float = float(s["t"]) / float(s["life"])
		draw_circle(s["pos"], float(s["size"]) * (0.6 + 0.9 * k2), Color(0.82, 0.82, 0.86, 0.6 * (1.0 - k2)))
	draw_set_transform_matrix(Transform2D.IDENTITY)


## A standing lantern left of the pirate with a flickering warm glow that lights the area around it.
func _draw_lantern(origin: Vector2, u: float, t: float) -> void:
	var pos := origin + Vector2(-34.0, -4.0) * u
	var flick := 0.9 + 0.1 * sin(t * 9.0) + 0.05 * sin(t * 23.0)
	for i in 4:
		var r := (150.0 - i * 28.0) * u * flick
		draw_circle(pos + Vector2(0.0, -26.0 * u), r, Color(1.0, 0.72, 0.3, 0.05 + 0.025 * i))
	var w := 16.0 * u
	var h := 26.0 * u
	draw_rect(Rect2(pos + Vector2(-w * 0.55, -h - 4.0 * u), Vector2(w * 1.1, 4.0 * u)), Color("2b1b16"))
	draw_rect(Rect2(pos + Vector2(-w / 2.0, -h), Vector2(w, h)), Color("2b1b16"))
	draw_rect(Rect2(pos + Vector2(-w / 2.0 + 3.0, -h + 3.0), Vector2(w - 6.0, h - 6.0)), Color(1.0, 0.82, 0.38))
	draw_rect(Rect2(pos + Vector2(-w * 0.55, -3.0 * u), Vector2(w * 1.1, 4.0 * u)), Color("2b1b16"))
	draw_circle(pos + Vector2(0.0, -h * 0.5), 4.0 * u * flick, Color(1.0, 0.98, 0.8))
