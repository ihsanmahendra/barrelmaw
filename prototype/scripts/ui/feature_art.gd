class_name FeatureArt
extends RefCounted
## Art for the next features (design/mockups at 7cf5814): the Daily Haul and Captain's Log menu icons, the
## three boss rule emblems, their strike effects and the elite rule icons. Painted like the rest of the game:
## dark outline, lit from above. Nothing here sets a draw transform, so it works inside any caller's
## transform. Strike effects take a progress k from 0 to 1 that the caller animates.

const OUT := Color("3a1f12")
const BOSS_COLORS: Dictionary = {
	"ghost": {"light": Color("8ff0e4"), "dark": Color("123c46")},  # Ghost Tide
	"armor": {"light": Color("c9d4e8"), "dark": Color("27304a")},  # Iron Kraken
	"curse": {"light": Color("d7b3ff"), "dark": Color("321c4a")},  # Skull Storm
}


# ---------- menu icons ----------

## Daily Haul: a sack of treasure under a rising sun, on a pale medallion so it reads on any button color.
## size is the width of the square it fills.
static func draw_haul_icon(c: CanvasItem, center: Vector2, size: float) -> void:
	_disc(c, center, 47.0 * size / 100.0, Color("fff1cf"), 3.5 * size / 100.0)
	var u := size * 0.8 / 100.0
	var sun := center + Vector2(14, -16) * u
	for i in 10:
		var dir := Vector2.from_angle(TAU * float(i) / 10.0)
		_poly(c, [sun + dir.rotated(-0.2) * 22.0 * u, sun + dir * 34.0 * u, sun + dir.rotated(0.2) * 22.0 * u],
			Color("ffe27a"), Color("ffb52e"), u * 2.0)
	_disc(c, sun, 21.0 * u, Color("ffd23f"), u * 3.0)
	# Coins peeping out of the neck, then the sack.
	for coin in [Vector2(-20, -12), Vector2(-6, -18), Vector2(6, -11)]:
		_disc(c, center + coin * u, 9.0 * u, Color("ffc93c"), u * 2.5)
	_poly(c, _at(center, u, [Vector2(-20, -8), Vector2(8, -8), Vector2(4, 2), Vector2(24, 16), Vector2(28, 34), Vector2(16, 44),
		Vector2(-28, 44), Vector2(-40, 34), Vector2(-36, 16), Vector2(-16, 2)]), Color("d9a566"), Color("8a5a30"), u * 4.0)
	_poly(c, _at(center, u, [Vector2(-19, -2), Vector2(7, -2), Vector2(5, 6), Vector2(-17, 6)]), Color("ef5a63"), Color("b92b3a"), u * 3.0)
	_disc(c, center + Vector2(-6, 25) * u, 10.0 * u, Color("ffd23f"), u * 3.0)


## Captain's Log: a closed leather book with a brass clasp, a skull on the cover and a red ribbon.
static func draw_log_icon(c: CanvasItem, center: Vector2, size: float) -> void:
	_disc(c, center, 47.0 * size / 100.0, Color("fff1cf"), 3.5 * size / 100.0)
	var u := size * 0.74 / 100.0
	_poly(c, _at(center, u, [Vector2(-34, -36), Vector2(34, -36), Vector2(38, -30), Vector2(38, 40), Vector2(-30, 42), Vector2(-36, 34)]),
		Color("fff1cf"), Color("cfb07a"), u * 4.0)  # pages
	_poly(c, _at(center, u, [Vector2(-38, -42), Vector2(28, -42), Vector2(32, -38), Vector2(32, 34), Vector2(28, 38), Vector2(-38, 38)]),
		Color("a8572f"), Color("5d2a17"), u * 4.0)  # cover
	c.draw_line(center + Vector2(-28, -40) * u, center + Vector2(-28, 36) * u, OUT, u * 3.0, true)
	_poly(c, _at(center, u, [Vector2(12, 34), Vector2(24, 34), Vector2(24, 50), Vector2(18, 44), Vector2(12, 50)]),
		Color("ef5a63"), Color("b92b3a"), u * 3.0)  # bookmark
	_skull(c, center + Vector2(1, -6) * u, 15.0 * u, 0.0)
	_poly(c, _at(center, u, [Vector2(20, -7), Vector2(38, -7), Vector2(38, 7), Vector2(20, 7)]), Color("ffe08a"), Color("c99a2c"), u * 3.0)


# ---------- boss rule emblems ----------

## A round badge in the rule's colors with its picture. size is the badge's diameter.
static func draw_boss_emblem(c: CanvasItem, center: Vector2, size: float, rule: String) -> void:
	if not BOSS_COLORS.has(rule):
		return
	var light: Color = BOSS_COLORS[rule]["light"]
	var dark: Color = BOSS_COLORS[rule]["dark"]
	var u := size / 100.0
	_disc(c, center, 47.0 * u, light, u * 4.0)
	c.draw_circle(center, 39.0 * u, dark, true, -1.0, true)
	c.draw_arc(center, 39.0 * u, 0.0, TAU, 40, OUT, u * 2.5, true)
	match rule:
		"ghost":
			PirateArt.draw_barrel(c, center + Vector2(0, -7) * u, 36.0 * u, 44.0 * u, Color("4cc9f0"))
			c.draw_circle(center + Vector2(0, -7) * u, 22.0 * u, Color(light, 0.28), true, -1.0, true)
			for row in 2:  # the water it rises from
				var wave := PackedVector2Array()
				for i in 17:
					var x := -30.0 + 60.0 * float(i) / 16.0
					wave.append(center + Vector2(x, 14.0 + row * 11.0 + sin(x * 0.22 + row * 1.7) * 3.5) * u)
				c.draw_polyline(wave, light, u * 5.0, true)
		"armor":
			_tentacle(c, _curve([center + Vector2(-16, 34) * u, center + Vector2(-28, -6) * u, center + Vector2(2, -34) * u,
				center + Vector2(24, -12) * u, center + Vector2(8, 4) * u]), 11.0 * u, 2.5 * u, light, u * 2.5)
			_hoop(c, center + Vector2(10, 22) * u, 16.0 * u, u)
		"curse":
			for s in [Vector2(-20, -22), Vector2(0, -27), Vector2(20, -22)]:
				c.draw_line(center + s * u, center + (s + Vector2(-3, 10)) * u, Color(light, 0.8), u * 3.5, true)
			_skull(c, center + Vector2(0, 8) * u, 19.0 * u, 0.0)


# ---------- strike effects (k from 0 to 1) ----------

## Ghost Tide: a smashed barrel floats back up into its cell, in a pale ring with an arrow pointing up. The
## ring and arrow stay bright to the end, because the board's barrels are often the same color.
static func draw_rising_barrel(c: CanvasItem, center: Vector2, cell: float, barrel_color: Color, k: float) -> void:
	var light: Color = BOSS_COLORS["ghost"]["light"]
	var dark: Color = BOSS_COLORS["ghost"]["dark"]
	var up := ease(clampf(k, 0.0, 1.0), 0.4)
	var at := center + Vector2(0, cell * (0.7 * (1.0 - up) - 0.12 * up))
	c.draw_circle(at, cell * 0.78, Color(light, 0.5), true, -1.0, true)
	c.draw_circle(at, cell * 0.6, Color(dark, 0.9), true, -1.0, true)
	c.draw_arc(at, cell * 0.65, 0.0, TAU, 24, Color.WHITE, maxf(2.0, cell * 0.09), true)
	PirateArt.draw_barrel(c, at, cell * (0.78 + 0.34 * up), cell * (0.84 + 0.36 * up), barrel_color)
	c.draw_circle(at, cell * 0.42, Color(light, 0.55 * (1.0 - up)), true, -1.0, true)
	var tip := at + Vector2(0, -cell * (0.98 + 0.08 * sin(k * 12.0)))
	_poly(c, [tip, tip + Vector2(0.3, 0.32) * cell, tip + Vector2(0.12, 0.32) * cell, tip + Vector2(0.12, 0.56) * cell,
		tip + Vector2(-0.12, 0.56) * cell, tip + Vector2(-0.12, 0.32) * cell, tip + Vector2(-0.3, 0.32) * cell],
		Color.WHITE, light, maxf(1.5, cell * 0.07))
	for i in 3:  # bubbles
		var phase := fposmod(k * 1.4 + float(i) * 0.33, 1.0)
		var bubble := center + Vector2((float(i) - 1.0) * cell * 0.5, cell * (0.6 - phase * 1.2))
		c.draw_arc(bubble, cell * 0.08, 0.0, TAU, 10, Color(1, 1, 1, 1.0 - phase), 1.8, true)


## Iron Kraken: one great tentacle reaches from `from` toward `to`, sweeping, and withdraws.
static func draw_tentacle(c: CanvasItem, from: Vector2, to: Vector2, t: float) -> void:
	var k := clampf(t, 0.0, 1.0)
	var reach := sin(PI * k)
	if reach <= 0.02:
		return
	# It starts a little way in from `from` and sways little, so it stays on the board it is given.
	var length := from.distance_to(to)
	var dir := (to - from).normalized()
	var start := from + dir * length * 0.1
	var along := (to - dir * length * 0.04 - start) * reach
	var side := dir.orthogonal() * length * reach
	var wave := lerpf(-0.05, 0.05, k)
	var spine := _curve([start, start + along * 0.34 + side * (wave - 0.05), start + along * 0.68 + side * (wave + 0.1),
		start + along + side * wave, start + along * 0.88 + side * (wave - 0.07)])
	_tentacle(c, spine, length * 0.052, length * 0.01, Color("8f7fc0"), maxf(2.0, length * 0.006))


## Iron Kraken: iron hoops fly in from above and below and clamp around a barrel.
static func draw_iron_clamp(c: CanvasItem, center: Vector2, cell: float, k: float) -> void:
	var t := ease(clampf(k, 0.0, 1.0), 2.2)
	for side in [-1.0, 1.0]:
		var at := center + Vector2(0, float(side) * cell * lerpf(1.1, 0.2, t))
		_hoop(c, at, cell * 0.46, cell / 40.0)
	if k > 0.8:  # the clang
		var flash := 1.0 - (k - 0.8) / 0.2
		c.draw_circle(center, cell * (0.3 + 0.4 * (1.0 - flash)), Color(1, 1, 1, 0.7 * flash), true, -1.0, true)


## Skull Storm: a skull tumbles down onto its barrel with a violet trail, and bursts as it lands.
static func draw_falling_skull(c: CanvasItem, target: Vector2, cell: float, k: float) -> void:
	var light: Color = BOSS_COLORS["curse"]["light"]
	var t := ease(clampf(k / 0.8, 0.0, 1.0), 2.0)
	var at := target + Vector2(cell * 0.7, -cell * 4.0) * (1.0 - t)
	if k < 0.8:
		for i in range(5, 0, -1):
			var back := at + Vector2(cell * 0.7, -cell * 4.0).normalized() * cell * 0.22 * float(i)
			c.draw_circle(back, cell * (0.3 - 0.035 * float(i)), Color(light, 0.34 - 0.05 * float(i)), true, -1.0, true)
		_skull(c, at, cell * 0.34, (1.0 - t) * 2.5)
	else:
		var burst := (k - 0.8) / 0.2
		c.draw_circle(target, cell * (0.35 + 0.55 * burst), Color(light, 0.65 * (1.0 - burst)), true, -1.0, true)
		_skull(c, target, cell * 0.34, 0.0)


# ---------- elite rules ----------

## Map and pop-up badge for an elite rule; mod is a key of Stages.ELITE_TEXT: "keg", "iron" or "short".
static func draw_elite_icon(c: CanvasItem, center: Vector2, size: float, mod: String) -> void:
	var u := size / 100.0
	_disc(c, center, 47.0 * u, Color("f0a03c"), u * 4.0)
	c.draw_circle(center, 38.0 * u, Color("5a3018"), true, -1.0, true)
	if mod.begins_with("keg"):  # Powder Keg: a barrel with a lit fuse
		PirateArt.draw_barrel(c, center + Vector2(-3, 7) * u, 44.0 * u, 52.0 * u, Color("a47148"))
		c.draw_polyline(PackedVector2Array([center + Vector2(0, -18) * u, center + Vector2(8, -28) * u, center + Vector2(18, -25) * u]), Color("ffe8c0"), u * 4.0, true)
		_poly(c, _star(center + Vector2(21, -25) * u, 13.0 * u, 5.0 * u, 7), Color("fff08a"), Color("ff7a1a"), u * 2.0)
	elif mod.begins_with("iron"):  # Iron Hull: a riveted plate
		_poly(c, _at(center, u, [Vector2(-24, -24), Vector2(24, -24), Vector2(22, 8), Vector2(0, 30), Vector2(-22, 8)]),
			Color("e6ecf8"), Color("6f7b93"), u * 4.0)
		c.draw_line(center + Vector2(-23, -6) * u, center + Vector2(23, -6) * u, OUT, u * 3.0, true)
		for r in [Vector2(-15, -15), Vector2(15, -15), Vector2(-12, 5), Vector2(12, 5), Vector2(0, 18)]:
			_disc(c, center + r * u, 3.6 * u, Color("c9d4e8"), u * 2.0)
	else:  # Short Hand: two cards and a red stroke where the third would be
		for card in [[Vector2(-15, 2), -0.22], [Vector2(5, -2), 0.08]]:
			var pos: Vector2 = center + (card[0] as Vector2) * u
			var angle: float = card[1]
			var pts: Array = []
			for corner in [Vector2(-12, -19), Vector2(12, -19), Vector2(12, 19), Vector2(-12, 19)]:
				pts.append(pos + (corner as Vector2).rotated(angle) * u)
			_poly(c, pts, Color("6aa3e0"), Color("2c5688"), u * 3.5)
		c.draw_line(center + Vector2(14, 12) * u, center + Vector2(30, 28) * u, OUT, u * 9.0, true)
		c.draw_line(center + Vector2(30, 12) * u, center + Vector2(14, 28) * u, OUT, u * 9.0, true)
		c.draw_line(center + Vector2(14, 12) * u, center + Vector2(30, 28) * u, Color("ff5a5a"), u * 5.0, true)
		c.draw_line(center + Vector2(30, 12) * u, center + Vector2(14, 28) * u, Color("ff5a5a"), u * 5.0, true)


# ---------- building blocks ----------

static func _at(center: Vector2, u: float, local: Array) -> Array:
	return local.map(func(p: Vector2) -> Vector2: return center + p * u)


## A filled, outlined polygon, lighter at the top.
static func _poly(c: CanvasItem, points: Array, top: Color, bottom: Color, outline: float) -> void:
	var pts := PackedVector2Array(points)
	var lo := INF
	var hi := -INF
	for p in pts:
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bottom, (p.y - lo) / maxf(1.0, hi - lo)))
	c.draw_polygon(pts, cols)
	var closed := pts.duplicate()
	closed.append(pts[0])
	c.draw_polyline(closed, OUT, outline, true)


static func _disc(c: CanvasItem, center: Vector2, r: float, col: Color, outline: float) -> void:
	c.draw_circle(center, r + outline, OUT, true, -1.0, true)
	c.draw_circle(center, r, col.darkened(0.14), true, -1.0, true)
	c.draw_circle(center + Vector2(-r * 0.08, -r * 0.12), r * 0.84, col, true, -1.0, true)


static func _star(center: Vector2, outer: float, inner: float, points: int) -> Array:
	var pts: Array = []
	for i in points * 2:
		pts.append(center + Vector2.from_angle(PI * float(i) / float(points)) * (outer if i % 2 == 0 else inner))
	return pts


static func _skull(c: CanvasItem, center: Vector2, r: float, angle: float) -> void:
	var rot := func(v: Vector2) -> Vector2: return center + v.rotated(angle) * r
	var head: Array = []
	for i in 15:  # the dome, then the jaw
		head.append(rot.call(Vector2.from_angle(PI * 0.78 + TAU * 0.72 * float(i) / 14.0)))
	head.append_array([rot.call(Vector2(0.55, 0.72)), rot.call(Vector2(0.5, 1.15)), rot.call(Vector2(-0.5, 1.15)), rot.call(Vector2(-0.55, 0.72))])
	_poly(c, head, Color("fffaf0"), Color("d9c9a8"), maxf(1.2, r * 0.17))
	for x in [-0.4, 0.4]:
		c.draw_circle(rot.call(Vector2(x, 0.05)), r * 0.27, Color("2a1233"), true, -1.0, true)
	c.draw_colored_polygon(PackedVector2Array([rot.call(Vector2(0, 0.35)), rot.call(Vector2(0.14, 0.6)), rot.call(Vector2(-0.14, 0.6))]), Color("2a1233"))
	for x in [-0.2, 0.2]:
		c.draw_line(rot.call(Vector2(x, 0.82)), rot.call(Vector2(x, 1.1)), Color("2a1233"), maxf(1.0, r * 0.09), true)


## An iron hoop seen from slightly above.
static func _hoop(c: CanvasItem, center: Vector2, r: float, u: float) -> void:
	var pts := PackedVector2Array()
	for i in 25:
		var a := TAU * float(i) / 24.0
		pts.append(center + Vector2(cos(a) * r, sin(a) * r * 0.36))
	c.draw_polyline(pts, OUT, maxf(3.5, 7.5 * u), true)
	c.draw_polyline(pts, Color("c9d4e8"), maxf(1.8, 4.0 * u), true)


## Points along a smooth curve through the control points.
static func _curve(ctrl: Array) -> Array:
	var out: Array = []
	for i in ctrl.size() - 1:
		var p0: Vector2 = ctrl[maxi(i - 1, 0)]
		var p1: Vector2 = ctrl[i]
		var p2: Vector2 = ctrl[i + 1]
		var p3: Vector2 = ctrl[mini(i + 2, ctrl.size() - 1)]
		for s in 7:
			var t := float(s) / 7.0
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	out.append(ctrl[ctrl.size() - 1])
	return out


## A tapering tentacle along spine, drawn as overlapping discs (so a tight curl never breaks the shape),
## with pale suckers along it.
static func _tentacle(c: CanvasItem, spine: Array, base_r: float, tip_r: float, col: Color, outline: float) -> void:
	var dense: Array = []
	for i in spine.size() - 1:
		for s in 4:
			dense.append((spine[i] as Vector2).lerp(spine[i + 1], float(s) / 4.0))
	var n := dense.size()
	for i in n:
		c.draw_circle(dense[i], lerpf(base_r, tip_r, float(i) / n) + outline, OUT, true, -1.0, true)
	for i in n:
		c.draw_circle(dense[i], lerpf(base_r, tip_r, float(i) / n), col.darkened(0.18), true, -1.0, true)
	for i in n:
		var r := lerpf(base_r, tip_r, float(i) / n)
		c.draw_circle((dense[i] as Vector2) + Vector2(-r, -r) * 0.18, r * 0.66, col, true, -1.0, true)
	for i in range(3, n - 4, maxi(3, n / 12)):
		var r := lerpf(base_r, tip_r, float(i) / n)
		var side := ((dense[i + 1] as Vector2) - (dense[i] as Vector2)).normalized().orthogonal()
		var at: Vector2 = (dense[i] as Vector2) - side * r * 0.42
		c.draw_circle(at, r * 0.34, Color("f2d9e8"), true, -1.0, true)
		c.draw_circle(at, r * 0.15, col.darkened(0.35), true, -1.0, true)
