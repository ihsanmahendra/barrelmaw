class_name BoardView
extends Control
## Draws the picture as smooth rounded cells and all board effects: bullets fired from the
## shooter, cell pops, particle bursts, screen shake, floating "+N" text, miss feedback and
## win confetti.
##
## Game logic resolves an action instantly. play_shots() replays it visually: cells that were
## removed stay on screen until their bullet lands.

signal shot_launched(index: int, kind: String)
signal shot_landed(index: int, count: int)
signal sequence_done(total: int)
## A special barrel triggered while shots land: "bomb", "ammo", "curse" or "iron".
signal special_event(kind: String)

const FLASH_TIME: float = 0.3
const POPUP_TIME: float = 0.9
const TRAVEL_TIME: float = 0.17
const RING_TIME: float = 0.18
const GAP: float = 3.0

var battle: Battle
var _ghost: Array = []
var _snapshot: Array = []
var _flashes: Dictionary = {}  # Vector2i -> [elapsed, Color]
var _parts: Array = []  # particles: pos, vel, t, life, color, size, grav
var _popups: Array = []  # floating text: pos, text, t, size, color
var _rings: Array = []  # muzzle flashes: pos, t, color
var _shake: float = 0.0
var _shake_offset: Vector2 = Vector2.ZERO
var _style := StyleBoxFlat.new()
var _outline := StyleBoxFlat.new()
var _overlay: Control
var _snap_special: Array = []  # special kinds before the latest action, for barrels still shown while their shot flies
var _blasts: Array = []  # bomb shock rings: pos, t
var _ov_accum: float = 0.0
var _cel: float = -1.0  # win celebration clock in seconds; -1 when it is not running
var _coins: Array = []  # falling doubloons: pos, vel, spin, spin_speed, size, delay

const REVEAL_TIME: float = 1.8  # the finished picture lights up over this long
const STAMP_AT: float = 1.7  # when the stamp slams down
const STAMP_SLAM: float = 0.28
## Cells the next shot will hit; shown as pulsing outlines. Set by the screen after each action.
var preview: Array = []
## Cells a card being previewed would remove itself (shown crossed out in orange).
var card_preview: Array = []

# Shot sequence state.
var _shots: Array = []  # launch, land, from, to, color, cells, anchor, index, kind, launched, landed
var _pending: Dictionary = {}  # Vector2i -> [pop_time, Color]: removed cells still shown
var _clock: float = 0.0
var _seq_active: bool = false
var _seq_end: float = 0.0
var _seq_total: int = 0


func _ready() -> void:
	set_process(false)
	resized.connect(queue_redraw)
	# The pulsing preview outlines live on a child overlay, so the barrels themselves are only
	# redrawn when something changes (not every frame).
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)



func set_battle(b: Battle) -> void:
	battle = b
	_ghost = b.board.cells.duplicate()
	_snapshot = b.board.cells.duplicate()
	_snap_special = b.board.special.duplicate()
	_blasts.clear()
	_coins.clear()
	_cel = -1.0
	set_process(true)
	_flashes.clear()
	_parts.clear()
	_popups.clear()
	_rings.clear()
	_shots.clear()
	_pending.clear()
	_seq_active = false
	_shake = 0.0
	queue_redraw()


func set_preview(cells: Array, from_card: Array = []) -> void:
	preview = cells
	card_preview = from_card
	set_process(true)
	_overlay.queue_redraw()
	queue_redraw()


func _has_specials() -> bool:
	if battle == null:
		return false
	for k in battle.board.special:
		if k != "":
			return true
	return false


func _cell_size() -> float:
	return minf(size.x / battle.board.w, size.y / battle.board.h)


func _origin(cs: float) -> Vector2:
	return (size - Vector2(battle.board.w, battle.board.h) * cs) / 2.0


func _cell_center(p: Vector2i, cs: float, origin: Vector2) -> Vector2:
	return origin + (Vector2(p) + Vector2(0.5, 0.5)) * cs


## Replays the latest action: bullets leave shooter_origin (board-local pixels) one after
## another and each removed cell pops when its bullet lands. Returns the total duration in
## seconds, or 0.0 when nothing was removed.
func play_shots(shooter_origin: Vector2) -> float:
	var cs := _cell_size()
	var origin := _origin(cs)
	var list: Array = battle.shots_last
	_shots.clear()
	_pending.clear()
	_seq_total = 0
	var gap := clampf(0.9 / maxf(1.0, float(list.size())), 0.04, 0.12)
	var end := 0.0
	for i in list.size():
		var s: Dictionary = list[i]
		var launch := gap * i
		var land := launch + TRAVEL_TIME
		var anchor: Vector2i = s["anchor"]
		var from_card: bool = s["kind"] == "card"
		var from_pos := Vector2(size.x / 2.0, size.y + 20.0) if from_card else shooter_origin
		var col := GameData.color_of(s["color"])
		for c in s["cells"]:
			var dist: int = absi(c.x - anchor.x) + absi(c.y - anchor.y)
			var pop := land + minf(0.3, 0.03 * dist)
			var letter: String = _snapshot[c.y * battle.board.w + c.x]
			_pending[c] = [pop, GameData.color_of(letter), _snap_special[c.y * battle.board.w + c.x]]
			end = maxf(end, pop)
			_seq_total += 1
		end = maxf(end, land)  # a shot with no broken barrels (iron only) still needs time to land
		_shots.append({
			"events": s.get("events", []),
			"launch": launch, "land": land, "from": from_pos,
			"to": _cell_center(anchor, cs, origin), "color": Color.WHITE if from_card else col,
			"cells": s["cells"], "anchor": anchor, "index": i, "kind": s["kind"],
			"launched": false, "landed": false,
		})
	_snapshot = battle.board.cells.duplicate()
	_snap_special = battle.board.special.duplicate()
	if _shots.is_empty():
		return 0.0
	_clock = 0.0
	_seq_end = end + 0.05
	_seq_active = true
	set_process(true)
	queue_redraw()
	return _seq_end


## Muzzle flash with no bullet, for a shot that found no target.
func show_dud(shooter_origin: Vector2) -> void:
	_rings.append({"pos": shooter_origin, "t": 0.0, "color": Color("a9adc8")})
	set_process(true)


## Grey "Miss" feedback with a small wobble.
func show_miss() -> void:
	_popups.append({"pos": size / 2.0, "text": "MISS", "t": 0.0, "size": 44, "color": Color("a9adc8")})
	_shake = maxf(_shake, 5.0)
	set_process(true)


## Confetti shower for a cleared picture.
## Win celebration, pirate style: the finished picture lights up barrel by barrel, a shower of spinning
## gold doubloons falls, and a "PLUNDERED!" stamp slams onto the board.
func celebrate() -> void:
	_cel = 0.0
	_coins.clear()
	for i in 70:
		_coins.append({
			"pos": Vector2(randf() * size.x, -20.0 - randf() * 120.0),
			"vel": Vector2(randf_range(-40.0, 40.0), randf_range(170.0, 330.0)),
			"spin": randf() * TAU, "spin_speed": randf_range(5.0, 11.0),
			"size": randf_range(11.0, 19.0), "delay": randf_range(0.0, 2.2),
		})
	_shake = maxf(_shake, 5.0)
	set_process(true)


func _burst(center: Vector2, color: Color, cs: float, count: int) -> void:
	for i in count:
		var ang := randf() * TAU
		var spd := randf_range(90.0, 260.0)
		_parts.append({
			"pos": center,
			"vel": Vector2(cos(ang), sin(ang)) * spd + Vector2(0.0, -60.0),
			"t": 0.0, "life": randf_range(0.45, 0.8), "color": color if randf() < 0.55 else Color("a8743f"),
			"size": cs * randf_range(0.14, 0.28), "grav": 520.0,
		})


func _process(delta: float) -> void:
	if _seq_active:
		_clock += delta
		_step_sequence()
	for p in _flashes.keys():
		_flashes[p][0] += delta
		if _flashes[p][0] >= FLASH_TIME:
			_flashes.erase(p)
	var alive: Array = []
	for pt in _parts:
		pt["t"] += delta
		if pt["t"] < pt["life"]:
			pt["vel"].y += pt["grav"] * delta
			pt["pos"] += pt["vel"] * delta
			alive.append(pt)
	_parts = alive
	var alive_popups: Array = []
	for pu in _popups:
		pu["t"] += delta
		if pu["t"] < POPUP_TIME:
			alive_popups.append(pu)
	_popups = alive_popups
	var alive_rings: Array = []
	for r in _rings:
		r["t"] += delta
		if r["t"] < RING_TIME:
			alive_rings.append(r)
	_rings = alive_rings
	_shake = _shake * exp(-10.0 * delta)
	if _shake < 0.3:
		_shake = 0.0
	if _cel >= 0.0:
		_cel += delta
		for c in _coins:
			if _cel >= float(c["delay"]):
				c["vel"].y += 260.0 * delta
				c["pos"] += c["vel"] * delta
				c["spin"] += float(c["spin_speed"]) * delta
		if _cel >= STAMP_AT and _cel - delta < STAMP_AT:  # the moment the stamp lands
			_shake = maxf(_shake, 14.0)
			for k in 18:
				var ang := TAU * float(k) / 18.0
				_parts.append({"pos": size / 2.0, "vel": Vector2(cos(ang), sin(ang)) * randf_range(160.0, 330.0), "t": 0.0, "life": randf_range(0.4, 0.8),
					"color": Color("c4284d") if k % 2 == 0 else Color("ffd166"), "size": randf_range(5.0, 10.0), "grav": 120.0})
	var alive_blasts: Array = []
	for bl in _blasts:
		bl["t"] += delta
		if bl["t"] < 0.45:
			alive_blasts.append(bl)
	_blasts = alive_blasts
	var animating := _seq_active or _cel >= 0.0 or not (_flashes.is_empty() and _parts.is_empty() and _popups.is_empty() and _rings.is_empty() and _blasts.is_empty()) or _shake > 0.0
	var pulsing := not (preview.is_empty() and card_preview.is_empty()) or _has_specials()
	if animating:
		queue_redraw()  # the barrels only redraw while something is actually moving
		_overlay.queue_redraw()
	_ov_accum += delta
	if pulsing and _ov_accum >= 1.0 / 24.0:  # the pulsing and flickering is smooth enough at 24 fps
		_ov_accum = 0.0
		_overlay.queue_redraw()
	if not animating and not pulsing:
		set_process(false)


func _step_sequence() -> void:
	var cs := _cell_size()
	var origin := _origin(cs)
	for s in _shots:
		if not s["launched"] and _clock >= s["launch"]:
			s["launched"] = true
			_rings.append({"pos": s["from"], "t": 0.0, "color": Color(1.0, 0.8, 0.3) if s["kind"] != "card" else Color(1, 1, 1)})
			shot_launched.emit(s["index"], s["kind"])
		if not s["landed"] and _clock >= s["land"]:
			s["landed"] = true
			_shake = maxf(_shake, 2.0 + minf(4.0, float(s["cells"].size())))
			shot_landed.emit(s["index"], s["cells"].size())
			for ev in s["events"]:
				_special_effect(ev, cs, origin)
	for p in _pending.keys():
		if _clock >= _pending[p][0]:
			var col: Color = _pending[p][1]
			_flashes[p] = [0.0, col]
			_burst(_cell_center(p, cs, origin), col, cs, 5 if _seq_total < 12 else 3)
			_pending.erase(p)
	if _clock >= _seq_end:
		_seq_active = false
		_finish_sequence(cs, origin)


## Visual and sound cue for a special barrel that just triggered.
func _special_effect(ev: Dictionary, cs: float, origin: Vector2) -> void:
	var pos := _cell_center(ev["pos"], cs, origin)
	match ev["kind"]:
		"bomb":
			_blasts.append({"pos": pos, "t": 0.0})
			_burst(pos, Color("ffb347"), cs * 1.6, 14)
			_burst(pos, Color("ff6a3d"), cs * 1.3, 10)
			_shake = maxf(_shake, 12.0)
			_popups.append({"pos": pos + Vector2(0, -cs * 0.4), "text": "BOOM!", "t": 0.0, "size": 30, "color": Color("ff9a3c")})
		"ammo":
			_burst(pos, Color("ffd166"), cs * 1.2, 10)
			_popups.append({"pos": pos + Vector2(0, -cs * 0.4), "text": "+%d hits" % int(ev["amount"]), "t": 0.0, "size": 30, "color": Color("ffd166")})
		"curse":
			_burst(pos, Color("8e3fd6"), cs * 1.2, 10)
			_shake = maxf(_shake, 5.0)
			_popups.append({"pos": pos + Vector2(0, -cs * 0.4), "text": "-%d hits" % int(ev["amount"]), "t": 0.0, "size": 30, "color": Color("c77dff")})
		"iron":
			_burst(pos, Color("b9c0d4"), cs, 6)
			_popups.append({"pos": pos + Vector2(0, -cs * 0.3), "text": "CLANG!", "t": 0.0, "size": 22, "color": Color("d6dbe8")})
	special_event.emit(ev["kind"])


func _finish_sequence(cs: float, origin: Vector2) -> void:
	var n := _seq_total
	if n > 0:
		var sum := Vector2.ZERO
		for s in _shots:
			sum += s["to"]
		var mid: Vector2 = sum / float(_shots.size())
		var big := n >= 6
		_popups.append({
			"pos": mid, "text": "+%d" % n, "t": 0.0,
			"size": 30 if n < 6 else (40 if n < 12 else 52),
			"color": Color("ffd166") if big else Color.WHITE,
		})
		if big:
			_shake = maxf(_shake, minf(16.0, 4.0 + float(n)))
		if n >= 12:
			_popups.append({"pos": mid + Vector2(0, -46), "text": "BIG HIT!", "t": 0.0, "size": 30, "color": Color("ef476f")})
	_shots.clear()
	sequence_done.emit(n)


func _draw_barrel_cell(r: Rect2, col: Color) -> void:
	PirateArt.draw_barrel(self, r.get_center(), r.size.x * 0.94, r.size.y, col)


func _cell_rect(x: int, y: int, cs: float, origin: Vector2) -> Rect2:
	return Rect2(origin + Vector2(x, y) * cs, Vector2(cs, cs)).grow(-GAP / 2.0)


func _fill(rect: Rect2, color: Color, radius: float) -> void:
	_style.bg_color = color
	_style.set_corner_radius_all(int(radius))
	_style.draw(get_canvas_item(), rect)


func _draw() -> void:
	if battle == null:
		return
	_shake_offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake)) if _shake > 0.0 else Vector2.ZERO
	draw_set_transform(_shake_offset)
	var bd := battle.board
	var cs := _cell_size()
	var origin := _origin(cs)
	# Wooden tray behind the picture so bright blocks read against the beach.
	var tray := Rect2(origin, Vector2(bd.w, bd.h) * cs).grow(10.0)
	_style.bg_color = Color(0.25, 0.16, 0.1, 0.86)
	_style.set_corner_radius_all(24)
	_style.set_border_width_all(5)
	_style.border_color = Color("8a5a30")
	_style.draw(get_canvas_item(), tray)
	_style.set_border_width_all(0)
	for y in bd.h:
		for x in bd.w:
			var r := _cell_rect(x, y, cs, origin)
			var ghost: String = _ghost[y * bd.w + x]
			var letter := bd.get_c(x, y)
			if letter == "":
				var key := Vector2i(x, y)
				if _pending.has(key):
					_draw_barrel_cell(r, _pending[key][1])  # removed, but its cannonball has not landed yet
				elif ghost != "":
					var wave_delay := float(bd.h - 1 - y) * 0.115 + float(x) * 0.03
					if _cel >= wave_delay:  # lit up by the win: the finished picture in full color
						var pop := clampf((_cel - wave_delay) / 0.4, 0.0, 1.0)
						var lit := Rect2(r.get_center() - r.size * (0.5 + 0.08 * sin(pop * PI)), r.size * (1.0 + 0.16 * sin(pop * PI)))
						_draw_barrel_cell(lit, GameData.color_of(ghost))
					else:
						var g := GameData.color_of(ghost)
						g.a = 0.14
						_fill(r, g, cs * 0.3)
				continue
			_draw_barrel_cell(r, GameData.color_of(letter))
	for bl in _blasts:
		var k: float = float(bl["t"]) / 0.45
		draw_circle(bl["pos"], cs * (0.5 + 2.2 * k), Color(1.0, 0.65, 0.2, 0.45 * (1.0 - k)))
		draw_arc(bl["pos"], cs * (0.6 + 2.6 * k), 0.0, TAU, 28, Color(1.0, 0.9, 0.5, 0.9 * (1.0 - k)), maxf(1.0, 7.0 * (1.0 - k)))
	_draw_bullets(cs)
	for p in _flashes.keys():
		var t: float = _flashes[p][0] / FLASH_TIME
		var col: Color = _flashes[p][1]
		col.a = 1.0 - t
		var r := _cell_rect(p.x, p.y, cs, origin).grow(cs * 0.25 * t)
		_fill(r, col, cs * 0.3)
		var core := Color(1, 1, 1, maxf(0.0, 0.8 - t * 2.0))
		_fill(_cell_rect(p.x, p.y, cs, origin).grow(-cs * 0.15), core, cs * 0.2)
	for pt in _parts:
		var k: float = 1.0 - float(pt["t"]) / float(pt["life"])
		var c: Color = pt["color"]
		c.a = clampf(k * 1.5, 0.0, 1.0)
		var s: float = float(pt["size"]) * (0.4 + 0.6 * k)
		_fill(Rect2(pt["pos"] - Vector2(s, s) / 2.0, Vector2(s, s)), c, s * 0.3)
	_draw_celebration(cs)
	var font := ThemeDB.fallback_font
	for pu in _popups:
		var k2: float = float(pu["t"]) / POPUP_TIME
		var rise: float = 50.0 * (1.0 - pow(1.0 - k2, 2.0))
		var alpha: float = 1.0 if k2 < 0.6 else (1.0 - (k2 - 0.6) / 0.4)
		var fs: int = int(float(pu["size"]) * (1.0 + 0.35 * maxf(0.0, 1.0 - k2 * 6.0)))
		var pos: Vector2 = pu["pos"] + Vector2(-150.0, -rise)
		var tc: Color = pu["color"]
		tc.a = alpha
		draw_string_outline(font, pos, pu["text"], HORIZONTAL_ALIGNMENT_CENTER, 300.0, fs, 8, Color(0.08, 0.09, 0.15, alpha))
		draw_string(font, pos, pu["text"], HORIZONTAL_ALIGNMENT_CENTER, 300.0, fs, tc)


func _draw_bullets(cs: float) -> void:
	for r in _rings:
		var k: float = float(r["t"]) / RING_TIME
		var c: Color = r["color"]
		c.a = 0.8 * (1.0 - k)
		draw_circle(r["pos"], cs * (0.3 + 0.8 * k), c)
	for s in _shots:
		if not s["launched"] or s["landed"]:
			continue
		var k: float = clampf((_clock - float(s["launch"])) / TRAVEL_TIME, 0.0, 1.0)
		var from: Vector2 = s["from"]
		var to: Vector2 = s["to"]
		var col: Color = s["color"]
		# Smoke trail behind the barrel.
		for j in range(5, 0, -1):
			var kt: float = maxf(0.0, k - 0.06 * j)
			var tp := from.lerp(to, kt * kt)
			draw_circle(tp, cs * (0.2 + 0.03 * j), Color(0.85, 0.85, 0.9, 0.38 - 0.06 * j))
		var pos := from.lerp(to, k * k)
		if s["kind"] == "card":
			draw_circle(pos, cs * 0.3, Color(1, 1, 1, 0.95))
			draw_circle(pos, cs * 0.18, col)
		else:
			PirateArt.draw_cannonball(self, pos, cs * 0.3, col)


## Pulsing outlines for the next shot (white) and for barrels a previewed card removes (orange).
## Drawn on the overlay control, so every call goes through _overlay.
func _draw_overlay() -> void:
	if battle == null:
		return
	_overlay.draw_set_transform(_shake_offset)
	var bd := battle.board
	var cs := _cell_size()
	var origin := _origin(cs)
	var canvas := _overlay.get_canvas_item()
	# Special barrel icons (live ones from the board, plus barrels still shown until their shot lands).
	var now := float(Time.get_ticks_msec()) / 1000.0
	for y in bd.h:
		for x in bd.w:
			var kind := bd.get_special(x, y)
			if kind != "":
				SpecialArt.draw_special(_overlay, origin + (Vector2(x, y) + Vector2(0.5, 0.5)) * cs, cs, kind, bd.get_hp(x, y), now)
	for pc in _pending.keys():
		var pk: String = _pending[pc][2]
		if pk != "":
			SpecialArt.draw_special(_overlay, origin + (Vector2(pc) + Vector2(0.5, 0.5)) * cs, cs, pk, 1, now)
	if _seq_active or (preview.is_empty() and card_preview.is_empty()):
		_overlay.draw_set_transform(Vector2.ZERO)
		return
	if not preview.is_empty():
		var pulse := 0.65 + 0.35 * sin(float(Time.get_ticks_msec()) / 160.0)
		_outline.bg_color = Color(1, 1, 1, 0.12 * pulse)
		_outline.set_border_width_all(4)
		_outline.border_color = Color(1, 1, 1, pulse)
		_outline.set_corner_radius_all(int(cs * 0.3))
		for c in preview:
			_outline.draw(canvas, _cell_rect(c.x, c.y, cs, origin).grow(1.0))
	if not card_preview.is_empty():
		var pulse2 := 0.65 + 0.35 * sin(float(Time.get_ticks_msec()) / 140.0)
		for c in card_preview:
			var cr := _cell_rect(c.x, c.y, cs, origin).grow(1.0)
			_outline.bg_color = Color(1.0, 0.5, 0.1, 0.3 * pulse2)
			_outline.set_border_width_all(4)
			_outline.border_color = Color(1.0, 0.6, 0.15, pulse2)
			_outline.set_corner_radius_all(int(cs * 0.3))
			_outline.draw(canvas, cr)
			_overlay.draw_line(cr.position + cr.size * 0.28, cr.position + cr.size * 0.72, Color(1, 0.95, 0.8, pulse2), 4.0)
			_overlay.draw_line(cr.position + Vector2(cr.size.x * 0.72, cr.size.y * 0.28), cr.position + Vector2(cr.size.x * 0.28, cr.size.y * 0.72), Color(1, 0.95, 0.8, pulse2), 4.0)
	_overlay.draw_set_transform(Vector2.ZERO)


## Gold doubloons that spin as they fall, and the "PLUNDERED!" stamp.
func _draw_celebration(cs: float) -> void:
	if _cel < 0.0:
		return
	for c in _coins:
		if _cel < float(c["delay"]):
			continue
		var p: Vector2 = c["pos"]
		if p.y > size.y + 30.0:
			continue
		var r: float = float(c["size"])
		var w := absf(cos(float(c["spin"]))) * r + 1.5  # a spinning coin is seen edge-on every half turn
		draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(0, 1), Vector2.ZERO))
		draw_circle(p + Vector2(2, 3), r, Color(0, 0, 0, 0.0))
		var shade := 0.75 + 0.25 * absf(cos(float(c["spin"])))
		_style.bg_color = Color("a8651a")
		_style.set_corner_radius_all(int(r))
		draw_style_box(_style, Rect2(p - Vector2(w + 2.0, r + 2.0), Vector2(w + 2.0, r + 2.0) * 2.0))
		_style.bg_color = Color(1.0 * shade, 0.82 * shade, 0.25 * shade)
		draw_style_box(_style, Rect2(p - Vector2(w, r), Vector2(w, r) * 2.0))
		if w > r * 0.5:
			draw_circle(p, r * 0.42, Color(0.72 * shade, 0.5 * shade, 0.1))
	var st := _cel - STAMP_AT
	if st < 0.0:
		return
	var k := clampf(st / STAMP_SLAM, 0.0, 1.0)
	var slam := 1.0 + 1.5 * (1.0 - k) * (1.0 - k)  # drops in from big, lands at 1.0
	var alpha := clampf(st / 0.2, 0.0, 1.0)
	var center := size / 2.0 + Vector2(0.0, size.y * 0.02)
	var m := Transform2D(Vector2(1, 0), Vector2(0, 1), Vector2.ZERO)
	m = Transform2D(-0.13, center) * Transform2D(Vector2(slam, 0.0), Vector2(0.0, slam), Vector2.ZERO)
	draw_set_transform_matrix(m)
	var font := UiKit.bold_font()
	var fs := int(clampf(size.x * 0.088, 26.0, 46.0))
	var text := "PLUNDERED!"
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var box := Rect2(Vector2(-tw / 2.0 - 22.0, -fs * 0.82), Vector2(tw + 44.0, fs * 1.4))
	var red := Color(0.78, 0.16, 0.3, alpha)
	_style.bg_color = Color(0.99, 0.94, 0.82, 0.92 * alpha)
	_style.set_corner_radius_all(10)
	draw_style_box(_style, box)
	# Ink rim like a rubber stamp: a thick border and a thin inner one.
	var rim := StyleBoxFlat.new()
	rim.bg_color = Color(0, 0, 0, 0)
	rim.set_corner_radius_all(10)
	rim.set_border_width_all(6)
	rim.border_color = red
	draw_style_box(rim, box)
	rim.set_border_width_all(2)
	draw_style_box(rim, box.grow(-12.0))
	draw_string(font, Vector2(-tw / 2.0, fs * 0.28), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, red)
	# Ring of ink that flies outward when it lands.
	if st > 0.0 and st < 0.5:
		var rk := st / 0.5
		draw_arc(Vector2.ZERO, tw * 0.5 + 40.0 + rk * 140.0, 0.0, TAU, 40, Color(0.78, 0.16, 0.3, 0.55 * (1.0 - rk)), maxf(1.0, 10.0 * (1.0 - rk)))
	draw_set_transform_matrix(Transform2D.IDENTITY)
