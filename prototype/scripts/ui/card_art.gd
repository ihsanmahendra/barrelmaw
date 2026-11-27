class_name CardArt
extends RefCounted
## The picture in the middle of a card, drawn in the painted style of the rest of the game: dark brown
## outlines, a lit and a shaded side, and the game's own barrel and cannonball textures. Each kind of
## effect has its own silhouette so cards can be told apart without reading them.

const OUT := Color("3a1f12")
const FIRE := Color("f26a1b")
const FIRE_LIGHT := Color("ffd23f")
const WOOD_PLATE := Color("5b3a22")
const BALL_RED := Color("ef476f")
const BALL_YELLOW := Color("ffd166")
const BALL_BLUE := Color("4cc9f0")
const BALL_GREEN := Color("06d6a0")
const BALL_PALE := Color("f6ead0")


## Draws the icon for card inside rect (about 120 x 52 design units).
static func draw(c: CanvasItem, rect: Rect2, card: Dictionary) -> void:
	var kinds := {}
	var shape := ""
	var ammo := 0
	var count := 0
	var ball_count := 1
	var wild_ball := false
	for e in card["effects"]:
		kinds[e["kind"]] = true
		if e["kind"] == "add_shooter":
			ball_count = int(e.get("count", 1))
			wild_ball = bool(e.get("wild", false))
		if e["kind"] == "shape":
			shape = e["shape"]
		if e["kind"] == "ammo":
			ammo += int(e["n"])
		if e.has("n"):
			count = maxi(count, int(e["n"]))
	var mid := rect.get_center()
	if card.get("rarity", "") in ["legendary", "transcended"]:
		var glint := Color("ffe27a") if card["rarity"] == "legendary" else Color("8ff5e4")
		_sparkle(c, Vector2(rect.position.x + 4.0, rect.position.y + 6.0), 7.0, glint)
		_sparkle(c, Vector2(rect.end.x - 3.0, rect.end.y - 10.0), 5.5, glint)
		_sparkle(c, Vector2(rect.end.x - 8.0, rect.position.y + 3.0), 4.0, glint)
	if shape != "":
		var has_badge := kinds.has("wild") or kinds.has("double") or ammo > 0
		var at := mid + Vector2(-15.0 if has_badge else 0.0, 0.0)
		_shape_board(c, at, 56.0, shape)
		if kinds.has("wild"):
			_ball_trio(c, Vector2(mid.x + 32.0, mid.y - 13.0), 0.5)
		if ammo > 0:
			_number(c, Vector2(mid.x + 18.0, mid.y + 21.0), "+%d" % ammo, 23)
		elif kinds.has("double"):
			_number(c, Vector2(mid.x + 19.0, mid.y + 12.0), "x2", 28)
		return
	if kinds.has("free_turn"):
		_compass(c, mid + Vector2(-20, 0), 26.0)
		_cards(c, mid + Vector2(24, -3), 2, 0.74)
		_number(c, mid + Vector2(22, 21), "+2", 21)
	elif kinds.has("repeat_last"):
		_cards(c, mid + Vector2(-16, 0), 2, 0.92)
		_loop_arrow(c, mid + Vector2(27, 0), 16.0, Color("4fe6cf"))
	elif kinds.has("clear_color"):
		_barrel_burst(c, mid + Vector2(-20, 0), [BALL_RED, BALL_RED, BALL_RED])
		_number(c, mid + Vector2(15, 11), "x%d" % count, 28)
	elif kinds.has("clear_random"):
		_barrel_burst(c, mid + Vector2(-20, 0), [BALL_BLUE, BALL_YELLOW, BALL_RED])
		_number(c, mid + Vector2(15, 11 if ammo == 0 else 4), "x%d" % count, 28)
		if ammo > 0:
			_number(c, mid + Vector2(17, 20), "+%d hit" % ammo, 14)
	elif kinds.has("chaos"):
		_die(c, mid, 25.0)
		_sparkle(c, mid + Vector2(-37, -9), 8.0, FIRE_LIGHT)
		_sparkle(c, mid + Vector2(37, 7), 10.0, FIRE_LIGHT)
		_sparkle(c, mid + Vector2(32, -18), 5.0, FIRE)
	elif kinds.has("wild"):
		_ball_trio(c, mid, 1.0)
		_sparkle(c, mid + Vector2(-38, -13), 8.0, FIRE_LIGHT)
		_sparkle(c, mid + Vector2(39, -9), 6.0, FIRE_LIGHT)
	elif kinds.has("double"):
		_speed_lines(c, mid + Vector2(-45, 0))
		_ball(c, mid + Vector2(-23, -4), 14.0, BALL_RED)
		_ball(c, mid + Vector2(-5, 6), 16.0, BALL_RED)
		_number(c, mid + Vector2(17, 11), "x2", 30)
	elif kinds.has("dup"):  # before "ammo": Clone also adds hits but must keep its own picture
		c.draw_circle(mid + Vector2(-22, 0), 18.0, Color(0.94, 0.28, 0.44, 0.35))
		_dashed_ring(c, mid + Vector2(-22, 0), 18.0)
		_arrow(c, mid + Vector2(-6, 0), mid + Vector2(9, 0), FIRE_LIGHT)
		_ball(c, mid + Vector2(25, 0), 18.0, BALL_RED)
		_sparkle(c, mid + Vector2(41, -15), 7.0, FIRE_LIGHT)
		if ammo > 0:
			_number(c, mid + Vector2(25, 20), "+%d" % ammo, 18)
	elif kinds.has("extra_play") and ammo > 0:  # Second Wind
		_extra_play_art(c, mid, "+%d" % ammo)
	elif kinds.has("ammo"):
		var with_draw := kinds.has("draw")
		var ball_at := mid + Vector2(-30.0 if with_draw else -17.0, 0)
		_flame(c, ball_at, 19.0)
		_ball(c, ball_at, 19.0, BALL_RED)
		if with_draw:
			_cards(c, mid + Vector2(40, -2), 1, 0.9)
			_number(c, mid + Vector2(-9, 12), "+%d" % ammo, 28)
		else:
			_number(c, mid + Vector2(9, 12), "+%d" % ammo, 34)
	elif kinds.has("add_shooter") and ball_count > 1:
		var col := BALL_PALE if wild_ball else BALL_RED  # pale balls are wild
		_ball(c, mid + Vector2(-15, -4), 18.0, col, str(count), 20)
		_ball(c, mid + Vector2(15, 5), 19.0, col, str(count), 21)
		_number(c, mid + Vector2(-55, 8), "x%d" % ball_count, 22)
		_plus_badge(c, mid + Vector2(38, -14), 9.0)
	elif kinds.has("add_shooter"):
		if count >= 5:  # a stack for the bigger delivery
			_ball(c, mid + Vector2(-23, 7), 13.0, BALL_RED.darkened(0.2))
			_ball(c, mid + Vector2(23, 7), 13.0, BALL_RED.darkened(0.2))
		_ball(c, mid + Vector2(0, 1), 21.0, BALL_RED, str(count), 24)
		_plus_badge(c, mid + Vector2(21, -15), 10.0)
	elif kinds.has("recolor_next"):
		_ball(c, mid + Vector2(-31, 0), 17.0, BALL_BLUE)
		_arrow(c, mid + Vector2(-10, 0), mid + Vector2(10, 0), FIRE_LIGHT)
		_ball(c, mid + Vector2(31, 0), 18.0, BALL_RED)
		_sparkle(c, mid + Vector2(47, -14), 7.0, FIRE_LIGHT)
	elif kinds.has("skip"):
		_ball(c, mid + Vector2(-28, 10), 14.0, BALL_RED)
		_ball(c, mid + Vector2(0, 10), 14.0, BALL_YELLOW)
		_ball(c, mid + Vector2(28, 10), 14.0, BALL_GREEN)
		var arc := PackedVector2Array()
		for i in 13:
			var a := PI + PI * 0.9 * float(i) / 12.0
			arc.append(mid + Vector2(cos(a) * 30.0, -2.0 + sin(a) * 21.0))
		_curved_arrow(c, arc, FIRE_LIGHT)
	elif kinds.has("draw"):
		_cards(c, mid + Vector2(-17, 0), maxi(2, count + 1), 1.0)
		_number(c, mid + Vector2(17, 12), "+%d" % count, 30)
	elif kinds.has("extra_play"):
		_extra_play_art(c, mid, "+1")


## "Play another card": a card pushed along by a gust of wind.
static func _extra_play_art(c: CanvasItem, mid: Vector2, label: String) -> void:
	for i in 3:  # a gust of wind behind the card
		var y := mid.y - 11.0 + i * 11.0
		var x := mid.x - 52.0 + (6.0 if i == 1 else 0.0)
		c.draw_line(Vector2(x, y), Vector2(x + 22.0, y), OUT, 5.0, true)
		c.draw_line(Vector2(x + 1.0, y), Vector2(x + 21.0, y), Color("bfe9ff"), 2.5, true)
	_cards(c, mid + Vector2(-10, 0), 1, 1.12)
	_shaded(c, PackedVector2Array([mid + Vector2(-16, -10), mid + Vector2(0, 0), mid + Vector2(-16, 10)]), FIRE_LIGHT, FIRE, 2.0)
	_number(c, mid + Vector2(17, 12), label, 30)


# ---------- building blocks ----------

## A filled shape lit from above, with the dark outline.
static func _shaded(c: CanvasItem, pts: PackedVector2Array, top: Color, bottom: Color, outline: float = 2.5) -> void:
	var lo := INF
	var hi := -INF
	for p in pts:
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bottom, (p.y - lo) / maxf(1.0, hi - lo)))
	c.draw_polygon(pts, cols)
	if outline > 0.0:
		_ring(c, pts, OUT, outline)


static func _ring(c: CanvasItem, pts: PackedVector2Array, col: Color, width: float) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	c.draw_polyline(closed, col, width, true)


static func _rounded(center: Vector2, size: Vector2, radius: float, angle: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var half := size / 2.0 - Vector2(radius, radius)
	var corners := [Vector2(half.x, half.y), Vector2(-half.x, half.y), Vector2(-half.x, -half.y), Vector2(half.x, -half.y)]
	for k in 4:
		for i in 5:
			var a := PI / 2.0 * k + PI / 2.0 * float(i) / 4.0
			pts.append(center + ((corners[k] as Vector2) + Vector2(cos(a), sin(a)) * radius).rotated(angle))
	return pts


static func _star(center: Vector2, outer: float, inner: float, points: int, angle: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points * 2:
		var r := outer if i % 2 == 0 else inner
		var a := angle + PI * float(i) / float(points)
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts


static func _sparkle(c: CanvasItem, center: Vector2, r: float, col: Color) -> void:
	_shaded(c, _star(center, r, r * 0.3, 4, -PI / 2.0), Color.WHITE.lerp(col, 0.4), col, 1.2)


## A gold number with a thick dark rim, as on the wooden signs.
static func _number(c: CanvasItem, pos: Vector2, text: String, size: int) -> void:
	var font := UiKit.bold_font()
	c.draw_string_outline(font, pos + Vector2(0, 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 8, OUT)
	c.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, FIRE_LIGHT)


static func _ball(c: CanvasItem, center: Vector2, r: float, col: Color, number: String = "", font_size: int = 20) -> void:
	c.draw_circle(center, r + 1.6, OUT, true, -1.0, true)
	PirateArt.draw_cannonball(c, center, r, col, number, font_size)


static func _ball_trio(c: CanvasItem, mid: Vector2, k: float) -> void:
	_ball(c, mid + Vector2(-21, 6) * k, 16.0 * k, BALL_RED)
	_ball(c, mid + Vector2(21, 6) * k, 16.0 * k, BALL_YELLOW)
	_ball(c, mid + Vector2(0, -4) * k, 19.0 * k, BALL_BLUE)


## A wooden plate showing which cells one hit clears: a fiery double-headed arrow along each line, or a
## burst over a 3x3 block.
static func _shape_board(c: CanvasItem, center: Vector2, size: float, shape: String) -> void:
	var half := size / 2.0
	_shaded(c, _rounded(center, Vector2(size, size), 9.0), WOOD_PLATE.lightened(0.14), WOOD_PLATE.darkened(0.2))
	for y in 5:
		for x in 5:
			c.draw_circle(center + Vector2(x - 2, y - 2) * (size * 0.18), 2.0, Color(1.0, 0.9, 0.7, 0.28))
	if shape == "blast":
		_shaded(c, _star(center, half * 1.14, half * 0.76, 10, 0.15), FIRE_LIGHT, FIRE, 2.2)
		for y in 3:
			for x in 3:
				var cell := center + Vector2(x - 1, y - 1) * 11.5
				_shaded(c, _rounded(cell, Vector2(10.0, 10.0), 2.5), Color("fff8d8"), Color("ffc93c"), 1.6)
		_ball(c, center, 5.0, Color("fff4dc"))
		return
	var angles: Array = []
	match shape:
		"row":
			angles = [0.0]
		"col":
			angles = [PI / 2.0]
		"cross":
			angles = [0.0, PI / 2.0]
		"diag":
			angles = [PI / 4.0, -PI / 4.0]
	var reach := half * (1.2 if shape == "diag" else 1.08)
	var single := angles.size() == 1
	var width := 8.5 if single else 6.0
	var arrows: Array = []
	for a in angles:
		arrows.append(_double_arrow(center, reach, width, a))
	for pts in arrows:  # all rims first, so crossing arrows merge into one shape
		_ring(c, pts, OUT, 5.0)
	for pts in arrows:
		c.draw_colored_polygon(pts, FIRE)
	for a in angles:
		var axis := Vector2.from_angle(a) * (reach - 10.0)
		c.draw_line(center - axis, center + axis, FIRE_LIGHT, width * 0.55, true)
	_ball(c, center, 8.0 if single else 7.0, Color("fff4dc"))


static func _double_arrow(center: Vector2, reach: float, width: float, angle: float) -> PackedVector2Array:
	var head := 11.0
	var w := width / 2.0
	var hw := width / 2.0 + 5.0
	var local := [Vector2(-reach, 0), Vector2(-reach + head, -hw), Vector2(-reach + head, -w), Vector2(reach - head, -w),
		Vector2(reach - head, -hw), Vector2(reach, 0), Vector2(reach - head, hw), Vector2(reach - head, w),
		Vector2(-reach + head, w), Vector2(-reach + head, hw)]
	var pts := PackedVector2Array()
	for p in local:
		pts.append(center + (p as Vector2).rotated(angle))
	return pts


static func _arrow(c: CanvasItem, from: Vector2, to: Vector2, col: Color) -> void:
	var dir := (to - from).normalized()
	var side := dir.orthogonal()
	var neck := to - dir * 9.0
	_shaded(c, PackedVector2Array([from + side * 3.5, neck + side * 3.5, neck + side * 9.0, to + dir * 2.0,
		neck - side * 9.0, neck - side * 3.5, from - side * 3.5]), col.lightened(0.25), col.darkened(0.15), 2.0)


static func _curved_arrow(c: CanvasItem, path: PackedVector2Array, col: Color) -> void:
	var tip := path[path.size() - 1]
	var dir := (tip - path[path.size() - 2]).normalized()
	var side := dir.orthogonal()
	c.draw_polyline(path, OUT, 7.5, true)
	var head := PackedVector2Array([tip + dir * 10.0, tip + side * 8.0, tip - side * 8.0])
	_ring(c, head, OUT, 3.5)
	c.draw_polyline(path, col, 4.0, true)
	c.draw_colored_polygon(head, col)


static func _loop_arrow(c: CanvasItem, center: Vector2, r: float, col: Color) -> void:
	var path := PackedVector2Array()
	for i in 17:
		var a := -PI * 0.25 + PI * 1.55 * float(i) / 16.0
		path.append(center + Vector2(cos(a), sin(a)) * r)
	_curved_arrow(c, path, col)


## Three barrels with a blast behind them and splinters flying.
static func _barrel_burst(c: CanvasItem, center: Vector2, colors: Array) -> void:
	_shaded(c, _star(center, 27.0, 16.0, 11, -0.2), FIRE_LIGHT, FIRE, 2.0)
	PirateArt.draw_barrel(c, center + Vector2(-11, -3), 19.0, 23.0, colors[0])
	PirateArt.draw_barrel(c, center + Vector2(11, -3), 19.0, 23.0, colors[1])
	PirateArt.draw_barrel(c, center + Vector2(0, 5), 24.0, 29.0, colors[2])
	for sp in [Vector3(-26, -15, 0.7), Vector3(24, -17, -0.8), Vector3(-27, 15, -0.4), Vector3(25, 16, 0.5)]:
		_shaded(c, _rounded(center + Vector2(sp.x, sp.y), Vector2(9.0, 4.0), 1.2, sp.z), Color("d89a55"), Color("8a5a30"), 1.4)


static func _flame(c: CanvasItem, center: Vector2, r: float) -> void:
	var outer := PackedVector2Array([center + Vector2(0, -r * 0.95), center + Vector2(-r * 1.05, -r * 1.0),
		center + Vector2(-r * 0.85, -r * 0.45), center + Vector2(-r * 1.85, -r * 0.25), center + Vector2(-r * 1.15, r * 0.1),
		center + Vector2(-r * 1.7, r * 0.65), center + Vector2(-r * 0.65, r * 0.65), center + Vector2(0, r * 0.95)])
	_shaded(c, outer, FIRE_LIGHT, FIRE, 2.0)


static func _speed_lines(c: CanvasItem, at: Vector2) -> void:
	for i in 3:
		var from := at + Vector2(-6.0 + (5.0 if i == 1 else 0.0), -11.0 + i * 11.0)
		c.draw_line(from, from + Vector2(11, 0), OUT, 5.0, true)
		c.draw_line(from + Vector2(1, 0), from + Vector2(10, 0), FIRE_LIGHT, 2.5, true)


static func _dashed_ring(c: CanvasItem, center: Vector2, r: float) -> void:
	for i in 9:
		var a := TAU * float(i) / 9.0
		c.draw_arc(center, r, a, a + 0.42, 6, OUT, 2.5, true)


static func _plus_badge(c: CanvasItem, center: Vector2, r: float) -> void:
	c.draw_circle(center, r + 2.0, OUT, true, -1.0, true)
	c.draw_circle(center, r, Color("3fae5a"), true, -1.0, true)
	c.draw_line(center - Vector2(r * 0.55, 0), center + Vector2(r * 0.55, 0), Color.WHITE, 3.0)
	c.draw_line(center - Vector2(0, r * 0.55), center + Vector2(0, r * 0.55), Color.WHITE, 3.0)


## A fan of playing card backs (blue with a gold diamond, like the draw pile).
static func _cards(c: CanvasItem, center: Vector2, n: int, k: float) -> void:
	for i in n:
		var t := i - (n - 1) / 2.0
		var angle := t * 0.22
		var at := center + Vector2(t * 12.0, absf(t) * 2.5) * k
		_shaded(c, _rounded(at, Vector2(28, 40) * k, 5.0 * k, angle), Color("5a93d1"), Color("2c5688"), 2.4)
		_ring(c, _rounded(at, Vector2(20, 32) * k, 3.0 * k, angle), Color("ffd98a"), 1.6)
		var gem := PackedVector2Array()
		for p in [Vector2(0, -8), Vector2(6, 0), Vector2(0, 8), Vector2(-6, 0)]:
			gem.append(at + (p * k).rotated(angle))
		_shaded(c, gem, Color("ffe9a8"), Color("e0a020"), 1.2)


static func _die(c: CanvasItem, center: Vector2, r: float) -> void:
	var angle := -0.2
	_shaded(c, _rounded(center + Vector2(2, 3), Vector2(r, r) * 1.8, 9.0, angle), Color("b9945f"), Color("8a6a40"), 2.5)
	_shaded(c, _rounded(center + Vector2(-1, -1), Vector2(r, r) * 1.7, 9.0, angle), Color("fffaf0"), Color("e6d2a8"), 2.0)
	for p in [Vector2(-11, -11), Vector2(11, -11), Vector2(0, 0), Vector2(-11, 11), Vector2(11, 11)]:
		var at: Vector2 = center + Vector2(-1, -1) + (p as Vector2).rotated(angle)
		c.draw_circle(at, 4.2, OUT if p != Vector2.ZERO else Color("d62839"), true, -1.0, true)


## A brass compass with a teal needle (Ghost Compass).
static func _compass(c: CanvasItem, center: Vector2, r: float) -> void:
	c.draw_circle(center, r + 2.0, OUT, true, -1.0, true)
	c.draw_circle(center, r, Color("c98a2e"), true, -1.0, true)
	c.draw_arc(center, r - 1.8, PI * 0.9, PI * 1.9, 20, Color("ffe08a"), 2.5, true)
	c.draw_circle(center, r * 0.76, OUT, true, -1.0, true)
	c.draw_circle(center, r * 0.7, Color("fbefd0"), true, -1.0, true)
	for k in 8:
		var dir := Vector2.from_angle(TAU * float(k) / 8.0)
		c.draw_line(center + dir * r * 0.5, center + dir * r * 0.64, Color("8a5a30"), 1.8, true)
	var up := Vector2(0, -r * 0.62).rotated(0.5)
	var side := Vector2(r * 0.17, 0).rotated(0.5)
	_shaded(c, PackedVector2Array([center + up, center + side, center - side]), Color("7ff3df"), Color("1fae9a"), 1.4)
	_shaded(c, PackedVector2Array([center - up, center + side, center - side]), Color("b0503a"), Color("6a2c20"), 1.4)
	c.draw_circle(center, 3.0, Color("ffe08a"), true, -1.0, true)
