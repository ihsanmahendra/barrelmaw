class_name MapDecor
extends RefCounted
## The things floating on the treasure map's open water, away from the path: reefs, sailing ships, a sea
## serpent, a shark, drifting barrels and a whale. Painted like the islands (dark outline, lit from above,
## a ring of foam) and tinted by `light` so they sink into the night sea.

const KINDS: int = 6
const SCALE: float = 1.3
const OUT := Color("3a1f12")


## Draws decoration number `kind` around p. t is time in seconds, light is white by day.
## c must have an identity draw transform; it is left that way.
static func draw(c: CanvasItem, p: Vector2, kind: int, t: float, light: Color) -> void:
	c.draw_set_transform(p * (1.0 - SCALE), 0.0, Vector2(SCALE, SCALE))  # grown about p
	match posmod(kind, KINDS):
		0:
			_reef(c, p, t, light)
		1:
			_ship(c, p, t, light)
		2:
			_serpent(c, p, t, light)
		3:
			_barrels(c, p, t, light)
		4:
			_shark(c, p, t, light)
		5:
			_whale(c, p, t, light)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The same decoration as a still picture (see BakedArt), tinted by light. Move p to make it bob.
static func draw_still(c: CanvasItem, p: Vector2, kind: int, light: Color) -> void:
	var k := posmod(kind, KINDS)
	BakedArt.draw_tinted(c, "decor:%d" % k, p, Rect2(-75.0, -70.0, 150.0, 140.0),
		func(item: CanvasItem, at: Vector2, col: Color) -> void: draw(item, at, k, 0.0, col), light)


static func _shape(c: CanvasItem, pts: PackedVector2Array, top: Color, bottom: Color, light: Color, outline: float = 2.2) -> void:
	var lo := INF
	var hi := -INF
	for q in pts:
		lo = minf(lo, q.y)
		hi = maxf(hi, q.y)
	var cols := PackedColorArray()
	for q in pts:
		cols.append(top.lerp(bottom, (q.y - lo) / maxf(1.0, hi - lo)) * light)
	c.draw_polygon(pts, cols)
	if outline > 0.0:
		var closed := pts.duplicate()
		closed.append(pts[0])
		c.draw_polyline(closed, OUT * light, outline, true)


## Broken ring of foam on the water, wider than tall.
static func _foam(c: CanvasItem, p: Vector2, rx: float, t: float, light: Color) -> void:
	var col := Color(1, 1, 1, 0.75) * light
	for i in 5:
		var a0 := TAU * float(i) / 5.0 + sin(t * 1.3 + float(i)) * 0.12
		var pts := PackedVector2Array()
		for k in 7:
			var a := a0 + 0.8 * float(k) / 6.0
			var wob := 1.0 + 0.05 * sin(t * 2.0 + float(i))
			pts.append(p + Vector2(cos(a) * rx, sin(a) * rx * 0.32) * wob)
		c.draw_polyline(pts, col, 3.0, true)


static func _reef(c: CanvasItem, p: Vector2, t: float, light: Color) -> void:
	_foam(c, p + Vector2(0, 6), 40.0, t, light)
	_shape(c, PackedVector2Array([p + Vector2(-30, 8), p + Vector2(-24, -8), p + Vector2(-12, -14), p + Vector2(-4, -2), p + Vector2(-8, 9)]), Color("b9b2a4"), Color("6d665e"), light)
	_shape(c, PackedVector2Array([p + Vector2(-8, 10), p + Vector2(-2, -18), p + Vector2(10, -26), p + Vector2(18, -8), p + Vector2(16, 10)]), Color("cbc4b4"), Color("746c62"), light)
	_shape(c, PackedVector2Array([p + Vector2(14, 10), p + Vector2(21, -4), p + Vector2(31, -6), p + Vector2(34, 9)]), Color("a8a195"), Color("625c55"), light)


static func _ship(c: CanvasItem, p: Vector2, t: float, light: Color) -> void:
	var q := p + Vector2(sin(t * 0.35 + p.y) * 14.0, sin(t * 1.6 + p.y) * 2.5)
	_foam(c, q + Vector2(0, 14), 34.0, t, light)
	c.draw_line(q + Vector2(0, 4), q + Vector2(0, -36), OUT * light, 3.5)
	_shape(c, PackedVector2Array([q + Vector2(2, -32), q + Vector2(17, -26), q + Vector2(21, -14), q + Vector2(16, -4), q + Vector2(2, -4)]), Color("fff7e2"), Color("d9c39a"), light)
	_shape(c, PackedVector2Array([q + Vector2(-3, -30), q + Vector2(-17, -20), q + Vector2(-20, -5), q + Vector2(-3, -5)]), Color("fff0cf"), Color("cdb488"), light)
	_shape(c, PackedVector2Array([q + Vector2(0, -36), q + Vector2(13, -33), q + Vector2(0, -29)]), Color("ef4757"), Color("b92b3a"), light, 1.4)
	_shape(c, PackedVector2Array([q + Vector2(-28, 0), q + Vector2(28, -2), q + Vector2(19, 14), q + Vector2(-18, 14)]), Color("a8672f"), Color("5d3519"), light)
	c.draw_line(q + Vector2(-24, 5), q + Vector2(24, 4), Color("f0c75a") * light, 2.5)


static func _serpent(c: CanvasItem, p: Vector2, t: float, light: Color) -> void:
	var green := Color("63d08a")
	var deep := Color("23795a")
	for hump in [Vector3(26, 6, 13), Vector3(0, 8, 17)]:  # humps behind the head
		var at := p + Vector2(hump.x, hump.y + sin(t * 1.8 + hump.x) * 2.0)
		var pts := PackedVector2Array()
		for i in 13:
			var a := PI + PI * float(i) / 12.0
			pts.append(at + Vector2(cos(a) * hump.z, sin(a) * hump.z))
		_shape(c, pts, green, deep, light)
		_foam(c, at, hump.z + 5.0, t, light)
	var head := p + Vector2(-27, -14 + sin(t * 1.8) * 2.5)
	_shape(c, PackedVector2Array([head + Vector2(-2, 24), head + Vector2(-4, 2), head + Vector2(-17, 0), head + Vector2(-19, -8), head + Vector2(-5, -17),
		head + Vector2(7, -12), head + Vector2(9, 0), head + Vector2(8, 24)]), green, deep, light)
	_shape(c, PackedVector2Array([head + Vector2(-2, -15), head + Vector2(3, -24), head + Vector2(7, -12)]), Color("ffd166"), Color("d08e1e"), light, 1.6)
	c.draw_circle(head + Vector2(-5, -8), 3.6, Color("fff4dc") * light, true, -1.0, true)
	c.draw_circle(head + Vector2(-6, -8), 1.8, OUT * light, true, -1.0, true)
	_foam(c, p + Vector2(-26, 10), 16.0, t, light)


static func _barrels(c: CanvasItem, p: Vector2, t: float, light: Color) -> void:
	for b in [Vector3(-14, 0, 0.0), Vector3(15, 8, 2.1)]:
		var at := p + Vector2(b.x, b.y + sin(t * 1.7 + b.z) * 2.5)
		PirateArt.draw_barrel(c, at, 24.0, 29.0, Color("a47148"))
		c.draw_rect(Rect2(at + Vector2(-14, 8), Vector2(28, 8)), Color(0.24, 0.68, 0.8, 0.75) * light)  # sits in the water
		_foam(c, at + Vector2(0, 9), 17.0, t, light)


static func _shark(c: CanvasItem, p: Vector2, t: float, light: Color) -> void:
	var q := p + Vector2(sin(t * 0.7 + p.y) * 20.0, 0.0)
	_shape(c, PackedVector2Array([q + Vector2(-13, 7), q + Vector2(-4, -10), q + Vector2(10, -17), q + Vector2(7, -5), q + Vector2(14, 7)]), Color("a9bccb"), Color("586d80"), light)
	_foam(c, q + Vector2(0, 7), 24.0, t, light)


static func _whale(c: CanvasItem, p: Vector2, t: float, light: Color) -> void:
	var q := p + Vector2(0, sin(t * 1.1 + p.y) * 2.5)
	_shape(c, PackedVector2Array([q + Vector2(28, 6), q + Vector2(36, -8), q + Vector2(31, -19), q + Vector2(40, -14), q + Vector2(49, -20), q + Vector2(45, -7), q + Vector2(39, 6)]),
		Color("6f9fd8"), Color("2f5590"), light)  # tail
	var pts := PackedVector2Array()
	for i in 17:
		var a := PI + PI * float(i) / 16.0
		pts.append(q + Vector2(cos(a) * 34.0, 8.0 + sin(a) * 22.0))
	_shape(c, pts, Color("6f9fd8"), Color("2f5590"), light)
	c.draw_circle(q + Vector2(-17, -1), 3.2, OUT * light, true, -1.0, true)
	c.draw_circle(q + Vector2(-18, -2), 1.1, Color.WHITE * light, true, -1.0, true)
	_foam(c, q + Vector2(0, 8), 42.0, t, light)
	var spout := fposmod(t * 0.45, 1.0)
	for i in 5:  # a puff of spray
		var side := float(i - 2)
		var at := q + Vector2(2.0 + side * 9.0 * spout, -16.0 - 20.0 * spout + absf(side) * 6.0 * spout)
		c.draw_circle(at, 3.6 * (1.0 - spout * 0.6), Color(1, 1, 1, 0.85 * (1.0 - spout)) * light, true, -1.0, true)
