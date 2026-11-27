class_name ChestArt
extends RefCounted
## Chests drawn in code, in the same painted style as the pirate, the barrels and the map chest: smooth
## shading with the light from the top left, outlines in a darker shade of each color (never black), glossy
## highlights, dark steel hoops with domed rivets, and a gold padlock. Five tiers differ in wood, metal and
## ornaments. draw() works on any CanvasItem whose transform is the identity.
## open_t 0 is shut, 1 is wide open: the lid swings up and back, light pours out and a treasure heap rises.
## t is time in seconds for glints and the Vault's wisps.

# wood: light, mid, dark; metal: light, mid, dark; line: the outline color.
const LOOKS: Dictionary = {
	"crate": {"wood": [Color("d39a58"), Color("a8672f"), Color("6f4120")], "metal": [Color("9ca3c0"), Color("555b78"), Color("2f3350")], "line": Color("3d2110"),
		"glow": Color("ffd9a0"), "coin": Color("e0a03a"), "gem": Color("e86a4a")},
	"iron": {"wood": [Color("8da3c8"), Color("5b6f96"), Color("38476a")], "metal": [Color("f2f5fb"), Color("b3bed1"), Color("6f7b93")], "line": Color("20293f"),
		"glow": Color("9fd4ff"), "coin": Color("d5dde9"), "gem": Color("4fb4ff")},
	"coffer": {"wood": [Color("b07be8"), Color("7e49bd"), Color("4b2a7c")], "metal": [Color("fff3c4"), Color("f0c75a"), Color("b9852a")], "line": Color("2b1549"),
		"glow": Color("d5a8ff"), "coin": Color("f5cd5e"), "gem": Color("ee5fdc")},
	"gilded": {"wood": [Color("f7c84a"), Color("d08e1e"), Color("8c5a10")], "metal": [Color("fff6c9"), Color("f7d366"), Color("c99a2c")], "line": Color("4d2e08"),
		"glow": Color("ffe08a"), "coin": Color("ffd84f"), "gem": Color("ff5a6e")},
	"vault": {"wood": [Color("46b3ac"), Color("217a75"), Color("114848")], "metal": [Color("e0fffa"), Color("86e0d2"), Color("3f9d97")], "line": Color("072b2e"),
		"glow": Color("3de0c8"), "coin": Color("86f2e3"), "gem": Color("b684ff")},
}
const GOLD: Array = [Color("fff4b8"), Color("f7cc4e"), Color("c4922a")]
# The treasure heap: x (-0.5..0.5 of the width), height above the rim, radius (of the width).
const HEAP: Array = [[-0.30, 0.02, 0.07], [-0.15, 0.03, 0.07], [0.0, 0.02, 0.07], [0.16, 0.03, 0.07], [0.30, 0.02, 0.07],
	[-0.22, 0.10, 0.065], [-0.07, 0.11, 0.065], [0.09, 0.10, 0.065], [0.24, 0.10, 0.065],
	[-0.14, 0.18, 0.06], [0.02, 0.19, 0.06], [0.16, 0.17, 0.06], [-0.04, 0.26, 0.055]]


static func look(chest_id: String) -> Dictionary:
	return LOOKS.get(chest_id, LOOKS["crate"])


static func glow_color(chest_id: String) -> Color:
	return look(chest_id)["glow"]


# ---------- painting helpers ----------

## Rounded rectangle as a polygon (so it can take a gradient and an outline).
static func _rrect(rect: Rect2, radius: float, seg: int = 5) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var corners := [[rect.end.x - r, rect.position.y + r, -PI / 2.0], [rect.end.x - r, rect.end.y - r, 0.0],
		[rect.position.x + r, rect.end.y - r, PI / 2.0], [rect.position.x + r, rect.position.y + r, PI]]
	for cn in corners:
		for i in range(seg + 1):
			var a: float = float(cn[2]) + (PI / 2.0) * float(i) / float(seg)
			pts.append(Vector2(float(cn[0]) + cos(a) * r, float(cn[1]) + sin(a) * r))
	return pts


## Colors for a polygon: a light at the top left easing to a dark at the bottom right. The blend is linear in
## x and y, so the shading is smooth whatever the triangulation. tones are the light, mid and dark of a material.
static func _tones(pts: PackedVector2Array, bounds: Rect2, tones: Array, tilt: float = 0.25) -> PackedColorArray:
	var cols := PackedColorArray()
	for p in pts:
		var ny := (p.y - bounds.position.y) / maxf(bounds.size.y, 1.0)
		var nx := (p.x - bounds.position.x) / maxf(bounds.size.x, 1.0)
		var k := clampf((1.0 - tilt) * ny + tilt * nx, 0.0, 1.0)
		var a: Color = tones[0]
		var b: Color = tones[1]
		var d: Color = tones[2]
		cols.append(a.lerp(b, k * 2.0) if k < 0.5 else b.lerp(d, (k - 0.5) * 2.0))
	return cols


## Filled, shaded and outlined polygon.
static func _paint(c: CanvasItem, pts: PackedVector2Array, bounds: Rect2, tones: Array, line: Color, line_w: float, tilt: float = 0.25) -> void:
	c.draw_polygon(pts, _tones(pts, bounds, tones, tilt))
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	c.draw_polyline(closed, line, line_w, true)


static func _dark(col: Color, amount: float = 0.45) -> Color:
	return col.darkened(amount)


static func _glint(c: CanvasItem, p: Vector2, r: float, a: float) -> void:
	var col := Color(1, 1, 1, a)
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r * 0.22, -r * 0.22), p + Vector2(r, 0), p + Vector2(r * 0.22, r * 0.22),
		p + Vector2(0, r), p + Vector2(-r * 0.22, r * 0.22), p + Vector2(-r, 0), p + Vector2(-r * 0.22, -r * 0.22)]), col)


## A domed rivet: dark rim, metal body and a bright spot, like the ones on the barrels.
static func _rivet(c: CanvasItem, p: Vector2, r: float, metal: Array, line: Color) -> void:
	c.draw_circle(p, r, line)
	c.draw_circle(p, r * 0.82, metal[1])
	c.draw_circle(p + Vector2(-r * 0.2, -r * 0.2), r * 0.55, metal[0])
	c.draw_circle(p + Vector2(-r * 0.3, -r * 0.35), r * 0.22, Color(1, 1, 1, 0.9))


## An upright hoop (a steel strap) from y0 to y1, shaded left to right.
static func _hoop(c: CanvasItem, cx: float, y0: float, y1: float, bw: float, metal: Array, line: Color, rivets: int) -> void:
	var rect := Rect2(Vector2(cx - bw / 2.0, y0), Vector2(bw, y1 - y0))
	var pts := _rrect(rect, bw * 0.18, 3)
	c.draw_polygon(pts, _tones(pts, rect, metal, 0.9))
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	c.draw_polyline(closed, _dark(metal[2], 0.35), maxf(1.5, bw * 0.09), true)
	c.draw_line(Vector2(cx - bw * 0.22, y0 + 3.0), Vector2(cx - bw * 0.22, y1 - 3.0), Color(1, 1, 1, 0.35), maxf(1.0, bw * 0.1))
	for i in rivets:
		var y := lerpf(y0, y1, (float(i) + 0.5) / float(rivets))
		_rivet(c, Vector2(cx, y), bw * 0.2, metal, line)


## A quad whose left and right edges have their own color: the soft side light and side shadow.
static func _fade(c: CanvasItem, x0: float, x1: float, y0: float, y1: float, left: Color, right: Color) -> void:
	c.draw_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]),
		PackedColorArray([left, right, right, left]))


## A horizontal metal band with a bright upper edge, a shaded lower edge and rivets.
static func _band(c: CanvasItem, rect: Rect2, metal: Array, line: Color, rivet_xs: Array) -> void:
	_paint(c, _rrect(rect, rect.size.y * 0.3, 3), rect, metal, _dark(metal[2], 0.45), maxf(1.5, rect.size.y * 0.16), 0.15)
	c.draw_line(Vector2(rect.position.x + 4.0, rect.position.y + rect.size.y * 0.28), Vector2(rect.end.x - 4.0, rect.position.y + rect.size.y * 0.28),
		Color(1, 1, 1, 0.45), maxf(1.0, rect.size.y * 0.14))
	for x in rivet_xs:
		_rivet(c, Vector2(float(x), rect.get_center().y), rect.size.y * 0.26, metal, line)


## Wavy grain and a knot or two on the planks.
static func _grain(c: CanvasItem, body: Rect2, line: Color) -> void:
	var w := body.size.x
	for k in 6:
		var x := body.position.x + w * (float(k) + 0.5) / 6.0
		var pts := PackedVector2Array()
		for i in 7:
			var u := float(i) / 6.0
			pts.append(Vector2(x + sin(u * 5.0 + float(k) * 2.1) * w * 0.018, body.position.y + body.size.y * (0.14 + 0.72 * u)))
		c.draw_polyline(pts, Color(line.r, line.g, line.b, 0.25), maxf(1.0, w * 0.007), true)
	for knot in [Vector2(0.08, 0.62), Vector2(0.58, 0.38), Vector2(0.92, 0.7)]:
		var at: Vector2 = body.position + body.size * (knot as Vector2)
		c.draw_circle(at, w * 0.015, Color(line.r, line.g, line.b, 0.45))
		c.draw_arc(at, w * 0.028, 0.0, TAU, 10, Color(line.r, line.g, line.b, 0.22), 1.0, true)


# ---------- the lid ----------

## Dome outline in lid space: bottom edge at y = 0, 2 * hw wide, rising to y = -lid_h.
static func _lid_points(hw: float, lid_h: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(-hw, 0), Vector2(-hw, -lid_h * 0.40)])
	for i in range(1, 19):
		var u := PI * float(i) / 18.0
		pts.append(Vector2(-hw * cos(u), -lid_h * (0.40 + 0.60 * sin(u))))
	pts.append(Vector2(hw, -lid_h * 0.40))
	pts.append(Vector2(hw, 0))
	return pts


static func _lid_top(x: float, hw: float, lid_h: float) -> float:
	var k := clampf(x / hw, -1.0, 1.0)
	return -lid_h * (0.40 + 0.60 * sqrt(maxf(0.0, 1.0 - k * k)))


## A strap over the dome, following its curve.
static func _lid_strap(c: CanvasItem, x: float, bw: float, hw: float, lid_h: float, metal: Array, line: Color, rivets: bool) -> void:
	var pts := PackedVector2Array([Vector2(x - bw / 2.0, 0)])
	for i in 9:
		var xx := x - bw / 2.0 + bw * float(i) / 8.0
		pts.append(Vector2(xx, _lid_top(xx, hw, lid_h)))
	pts.append(Vector2(x + bw / 2.0, 0))
	var bounds := Rect2(Vector2(x - bw / 2.0, -lid_h), Vector2(bw, lid_h))
	c.draw_polygon(pts, _tones(pts, bounds, metal, 0.9))
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	c.draw_polyline(closed, _dark(metal[2], 0.35), maxf(1.5, bw * 0.09), true)
	c.draw_line(Vector2(x - bw * 0.22, -3.0), Vector2(x - bw * 0.22, _lid_top(x - bw * 0.22, hw, lid_h) + 5.0), Color(1, 1, 1, 0.3), maxf(1.0, bw * 0.1))
	if rivets:
		for f in [0.22, 0.52]:
			var yy: float = lerpf(-4.0, _lid_top(x, hw, lid_h) + 6.0, f)
			_rivet(c, Vector2(x, yy), bw * 0.18, metal, line)


# ---------- the treasure ----------

static func _draw_heap(c: CanvasItem, body: Rect2, w: float, open_t: float, t: float, lk: Dictionary) -> void:
	var rim_y := body.position.y + 4.0
	var rise := clampf((open_t - 0.15) / 0.6, 0.0, 1.0)
	if rise <= 0.0:
		return
	var cx := body.get_center().x
	var coin: Color = lk["coin"]
	var mound := PackedVector2Array([Vector2(cx - w * 0.42, rim_y + 6.0), Vector2(cx - w * 0.36, rim_y - w * 0.07 * rise),
		Vector2(cx, rim_y - w * 0.15 * rise), Vector2(cx + w * 0.36, rim_y - w * 0.07 * rise), Vector2(cx + w * 0.42, rim_y + 6.0)])
	c.draw_colored_polygon(mound, coin.darkened(0.5))
	for i in HEAP.size():
		var h: Array = HEAP[i]
		var p := Vector2(cx + w * float(h[0]), rim_y - w * float(h[1]) * 0.75 * rise)
		var r := w * float(h[2]) * (0.6 + 0.4 * rise)
		if i % 5 == 2:  # a gem
			var g: Color = lk["gem"]
			var gp := PackedVector2Array([p + Vector2(0, -r * 1.15), p + Vector2(r * 0.95, 0), p + Vector2(0, r * 1.15), p + Vector2(-r * 0.95, 0)])
			c.draw_colored_polygon(gp, g.darkened(0.15))
			c.draw_colored_polygon(PackedVector2Array([gp[0], gp[1], p + Vector2(0, -r * 0.1)]), g.lightened(0.5))
			c.draw_colored_polygon(PackedVector2Array([gp[0], p + Vector2(0, -r * 0.1), gp[3]]), g.lightened(0.25))
			c.draw_polyline(PackedVector2Array([gp[0], gp[1], gp[2], gp[3], gp[0]]), g.darkened(0.55), maxf(1.0, r * 0.18), true)
		else:
			c.draw_circle(p, r, coin.darkened(0.55))
			c.draw_circle(p, r * 0.86, coin.darkened(0.12))
			c.draw_circle(p + Vector2(-r * 0.08, -r * 0.1), r * 0.7, coin.lightened(0.1))
			c.draw_arc(p + Vector2(-r * 0.08, -r * 0.08), r * 0.5, PI * 1.05, PI * 1.75, 6, Color(1, 1, 1, 0.7), maxf(1.0, r * 0.2))
	var tw := 0.5 + 0.5 * sin(t * 3.0)
	_glint(c, Vector2(cx - w * 0.12, rim_y - w * 0.2 * rise), w * 0.05 * rise, 0.5 + 0.5 * tw)
	_glint(c, Vector2(cx + w * 0.2, rim_y - w * 0.12 * rise), w * 0.04 * rise, 1.0 - 0.5 * tw)


# ---------- the whole chest ----------

## Draws a chest centered at `center`, `w` wide.
## How far below center the shut chest and its ground shadow reach.
static func bottom(w: float) -> float:
	return w * 0.5736 + 3.0


## Highest point reached by the light around an open chest. glow scales the aura and rays (1 is full size).
static func glow_top(center: Vector2, w: float, open_t: float, glow: float = 1.0) -> float:
	var origin_y := center.y + w * 0.84 * 0.04
	var aura := w * 0.94 * glow
	var ray := w * (0.85 + 0.65 * open_t) * glow if open_t > 0.05 else 0.0
	return origin_y - maxf(aura, ray + 2.0)


static func draw(c: CanvasItem, center: Vector2, w: float, chest_id: String, open_t: float = 0.0, t: float = 0.0, glow: float = 1.0) -> void:
	var lk := look(chest_id)
	var wood: Array = lk["wood"]
	var metal: Array = lk["metal"]
	var line: Color = lk["line"]
	var lw := maxf(2.2, w * 0.046)  # as heavy as the outlines of the painted pieces
	var h := w * 0.84
	var body_h := h * 0.5
	var body := Rect2(Vector2(center.x - w * 0.5, center.y + h * 0.04), Vector2(w, body_h))
	var hinge_y := body.position.y
	var lid_h := h * 0.42
	var hw := w * 0.515
	var gl: Color = lk["glow"]
	# Soft ground shadow.
	c.draw_set_transform(Vector2(center.x, body.end.y + 3.0), 0.0, Vector2(1.0, 0.2))
	c.draw_circle(Vector2.ZERO, w * 0.6, Color(0.08, 0.05, 0.1, 0.3))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Aura, stronger when open and ghostly for the Vault.
	var aura := 0.06 + 0.22 * open_t
	if chest_id == "vault":
		aura += 0.07 + 0.05 * sin(t * 2.4)
	for i in 4:
		c.draw_circle(Vector2(center.x, body.position.y), w * (0.55 + 0.13 * float(i)) * glow, Color(gl.r, gl.g, gl.b, aura * 0.35))
	# Rays of light when open.
	if open_t > 0.05:
		var origin := Vector2(center.x, hinge_y - 2.0)
		for i in 11:
			var a := -PI / 2.0 + (float(i) - 5.0) * 0.15
			var length := w * (0.85 + 0.65 * open_t) * glow * (0.8 + 0.2 * sin(t * 3.0 + float(i) * 1.7))
			var tip := origin + Vector2(cos(a), sin(a)) * length
			var side := Vector2(-sin(a), cos(a)) * (w * 0.02)
			c.draw_colored_polygon(PackedVector2Array([origin + side, origin - side, tip - side * 3.0, tip + side * 3.0]), Color(gl.r, gl.g, gl.b, 0.17 * open_t))
	# The lid once it is past upright: its padded inside shows above the back of the chest.
	var ang := open_t * PI * 0.76
	var fore := cos(ang)
	if fore < 0.0:
		c.draw_set_transform(Vector2(center.x, hinge_y - 4.0), 0.0, Vector2(1.0, -fore * 1.25))
		var outer := _lid_points(hw, lid_h)
		_paint(c, outer, Rect2(Vector2(-hw, -lid_h), Vector2(hw * 2.0, lid_h)), wood, line, lw, 0.2)
		var lining := _lid_points(hw * 0.8, lid_h * 0.8)
		var dark_wood: Color = wood[2]
		c.draw_polygon(lining, _tones(lining, Rect2(Vector2(-hw * 0.8, -lid_h * 0.8), Vector2(hw * 1.6, lid_h * 0.8)), [dark_wood.lightened(0.1), dark_wood.darkened(0.2), dark_wood.darkened(0.5)], 0.1))
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if open_t > 0.0:
		_draw_heap(c, body, w, open_t, t, lk)
	# Stubby metal feet.
	for fx in [-0.46, 0.31]:
		var foot := Rect2(Vector2(center.x + w * float(fx), body.end.y - w * 0.045), Vector2(w * 0.15, w * 0.105))
		_paint(c, _rrect(foot, w * 0.03, 3), foot, metal, line, lw * 0.7, 0.4)
	# Body: shaded planks with a dark outline.
	_paint(c, _rrect(body, w * 0.05, 5), body, wood, line, lw, 0.28)
	for k in 6:  # neighboring planks differ a little, and each one rounds off to the right
		var px := body.position.x + w * float(k) / 6.0
		var y0 := body.position.y + 3.0
		var y1 := body.end.y - 3.0
		if k % 2 == 1:
			c.draw_rect(Rect2(Vector2(px, y0), Vector2(w / 6.0, y1 - y0)), Color(1, 1, 1, 0.07))
		_fade(c, px + w * 0.08, px + w / 6.0 - 1.0, y0, y1, Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.2))
	# Vertical staves, like the barrels'.
	for k in range(1, 6):
		var sx := body.position.x + w * float(k) / 6.0
		c.draw_line(Vector2(sx, body.position.y + 4.0), Vector2(sx, body.end.y - 4.0), Color(line.r, line.g, line.b, 0.5), maxf(1.2, w * 0.011))
		c.draw_line(Vector2(sx + 1.8, body.position.y + 4.0), Vector2(sx + 1.8, body.end.y - 4.0), Color(1, 1, 1, 0.13), 1.2)
	_grain(c, body, line)
	# Highlight along the top edge, shadow at the foot.
	c.draw_line(Vector2(body.position.x + w * 0.06, body.position.y + 3.0), Vector2(body.end.x - w * 0.06, body.position.y + 3.0), Color(1, 1, 1, 0.3), maxf(1.5, w * 0.018))
	c.draw_rect(Rect2(Vector2(body.position.x + 3.0, body.end.y - w * 0.045), Vector2(w - 6.0, w * 0.04)), Color(0, 0, 0, 0.22))
	# Light from the left, shadow on the right side and under the lid.
	_fade(c, body.position.x + 3.0, body.position.x + w * 0.2, body.position.y + 3.0, body.end.y - 3.0, Color(1, 1, 1, 0.2), Color(1, 1, 1, 0.0))
	_fade(c, body.end.x - w * 0.26, body.end.x - 3.0, body.position.y + 3.0, body.end.y - 3.0, Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.34))
	var band_h := w * 0.075
	var rivet_xs := [center.x - w * 0.45, center.x + w * 0.45]
	if open_t > 0.15:  # with the lid up the body shows its own top rim
		_band(c, Rect2(Vector2(body.position.x - w * 0.012, body.position.y - 1.0), Vector2(w * 1.024, band_h)), metal, line, rivet_xs)
	else:
		c.draw_rect(Rect2(Vector2(body.position.x + 3.0, body.position.y + 1.0), Vector2(w - 6.0, w * 0.045)), Color(0, 0, 0, 0.28))
	_band(c, Rect2(Vector2(body.position.x - w * 0.012, body.end.y - band_h), Vector2(w * 1.024, band_h)), metal, line, rivet_xs)
	# Two steel hoops with domed rivets.
	var bw := w * 0.11
	for sx in [-0.34, 0.34]:
		_hoop(c, center.x + w * float(sx), body.position.y - 1.0, body.end.y + 1.0, bw, metal, line, 3)
	_tier_front(c, body, w, chest_id, lk, line)
	# The lid, closed or tipping up: its front face gets shorter as it goes back.
	if fore >= 0.0:
		c.draw_set_transform(Vector2(center.x, hinge_y), 0.0, Vector2(1.0, maxf(fore, 0.04)))
		var lid_bounds := Rect2(Vector2(-hw, -lid_h), Vector2(hw * 2.0, lid_h))
		_paint(c, _lid_points(hw, lid_h), lid_bounds, wood, line, lw, 0.22)
		# Staves converge over the dome.
		for k in range(1, 6):
			var sx2 := -hw + hw * 2.0 * float(k) / 6.0
			c.draw_line(Vector2(sx2, -3.0), Vector2(sx2, _lid_top(sx2, hw, lid_h) + 4.0), Color(line.r, line.g, line.b, 0.45), 1.5)
		# The dome turns away from the light toward the right.
		for i in 10:
			var xa := hw * (0.36 + 0.062 * float(i))
			var xb := hw * (0.36 + 0.062 * float(i + 1))
			c.draw_polygon(PackedVector2Array([Vector2(xa, _lid_top(xa, hw, lid_h) + 2.0), Vector2(xb, _lid_top(xb, hw, lid_h) + 2.0), Vector2(xb, -2.0), Vector2(xa, -2.0)]),
				PackedColorArray([Color(0, 0, 0, 0.035 * i), Color(0, 0, 0, 0.035 * (i + 1)), Color(0, 0, 0, 0.035 * (i + 1)), Color(0, 0, 0, 0.035 * i)]))
		# Glossy highlight sweeping over the top left of the dome.
		var gloss := PackedVector2Array()
		for i in range(2, 11):
			var u := PI * float(i) / 18.0
			gloss.append(Vector2(-hw * 0.92 * cos(u), -lid_h * (0.40 + 0.60 * sin(u)) * 0.9 - 3.0))
		c.draw_polyline(gloss, Color(1, 1, 1, 0.38), maxf(2.0, w * 0.03), true)
		# The metal rim along the bottom edge of the lid, then the straps over it.
		_band(c, Rect2(Vector2(-hw - w * 0.008, -w * 0.075), Vector2(hw * 2.0 + w * 0.016, w * 0.075)), metal, line, [-hw * 0.88, 0.0, hw * 0.88])
		for sx in [-0.34, 0.34]:
			_lid_strap(c, w * float(sx), bw, hw, lid_h, metal, line, true)
		_tier_lid(c, hw, lid_h, w, chest_id, lk)
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if open_t < 0.3:
			_lock(c, Vector2(center.x, hinge_y + 2.0), w, chest_id, lk, t)
	if open_t > 0.6:  # a few coins spill onto the ground
		var spill := clampf((open_t - 0.6) / 0.4, 0.0, 1.0)
		var coin: Color = lk["coin"]
		for sp in [Vector3(-0.56, 0.0, 0.055), Vector3(-0.47, 0.05, 0.045), Vector3(0.5, 0.045, 0.05), Vector3(0.58, -0.005, 0.04), Vector3(0.08, 0.075, 0.05)]:
			var at := Vector2(center.x + w * sp.x, body.end.y + w * sp.y)
			c.draw_set_transform(at, 0.0, Vector2(1.0, 0.65))
			c.draw_circle(Vector2.ZERO, w * sp.z * spill, line)
			c.draw_circle(Vector2.ZERO, w * sp.z * 0.8 * spill, coin.darkened(0.08))
			c.draw_circle(Vector2(-1, -2), w * sp.z * 0.45 * spill, coin.lightened(0.3))
			c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Glints on the metal.
	var tw := 0.5 + 0.5 * sin(t * 2.2 + w)
	_glint(c, Vector2(center.x - w * 0.34, body.position.y + body_h * 0.3), w * 0.035, 0.5 + 0.4 * tw)
	if chest_id == "vault":
		for i in 5:  # wisps rising off the Vault
			var phase := fposmod(t * 0.35 + float(i) * 0.2, 1.0)
			var wp := Vector2(center.x + w * (-0.4 + 0.2 * float(i)) + sin(t * 2.0 + float(i)) * 6.0, body.position.y - lid_h * 0.2 - phase * h * 0.7)
			c.draw_circle(wp, w * 0.035 * (1.0 - phase), Color(0.5, 1.0, 0.92, 0.45 * (1.0 - phase)))


## The padlock: gold like the map chest's, or a skull for the Vault, a gem for the Coffer, a crown for the Gilded.
static func _lock(c: CanvasItem, p: Vector2, w: float, chest_id: String, lk: Dictionary, t: float) -> void:
	var r := w * 0.1
	if chest_id == "vault":
		var pulse := 0.6 + 0.4 * sin(t * 3.0)
		c.draw_circle(p + Vector2(0, r * 0.3), r * 1.9, Color(0.24, 0.88, 0.78, 0.18 * pulse))
	var tones: Array = GOLD if chest_id != "vault" else [Color("c9fff5"), Color("5fe8d3"), Color("2a9f93")]
	var edge: Color = _dark(tones[2], 0.55)
	# Shackle.
	c.draw_arc(p + Vector2(0, -r * 0.1), r * 0.62, PI, TAU, 10, edge, maxf(3.0, r * 0.5), true)
	c.draw_arc(p + Vector2(0, -r * 0.1), r * 0.62, PI, TAU, 10, tones[1], maxf(1.5, r * 0.28), true)
	var plate := Rect2(p + Vector2(-r * 0.95, -r * 0.35), Vector2(r * 1.9, r * 2.0))
	_paint(c, _rrect(plate, r * 0.35, 4), plate, tones, edge, maxf(1.5, w * 0.02), 0.2)
	c.draw_line(plate.position + Vector2(r * 0.22, r * 0.2), plate.position + Vector2(r * 0.22, plate.size.y - r * 0.3), Color(1, 1, 1, 0.45), maxf(1.0, r * 0.14))
	var mid := plate.get_center() + Vector2(0, r * 0.05)
	match chest_id:
		"vault":
			c.draw_circle(mid + Vector2(-r * 0.3, -r * 0.05), r * 0.2, Color("0d3a3c"))
			c.draw_circle(mid + Vector2(r * 0.3, -r * 0.05), r * 0.2, Color("0d3a3c"))
			c.draw_rect(Rect2(mid + Vector2(-r * 0.18, r * 0.3), Vector2(r * 0.36, r * 0.3)), Color("0d3a3c"))
		"coffer":
			var g: Color = lk["gem"]
			var gp := PackedVector2Array([mid + Vector2(0, -r * 0.5), mid + Vector2(r * 0.5, 0), mid + Vector2(0, r * 0.6), mid + Vector2(-r * 0.5, 0)])
			c.draw_colored_polygon(gp, g.darkened(0.1))
			c.draw_colored_polygon(PackedVector2Array([gp[0], gp[1], mid]), g.lightened(0.5))
			c.draw_polyline(PackedVector2Array([gp[0], gp[1], gp[2], gp[3], gp[0]]), g.darkened(0.5), 1.5, true)
		"gilded":
			var cr := PackedVector2Array([mid + Vector2(-r * 0.5, r * 0.45), mid + Vector2(-r * 0.5, -r * 0.2), mid + Vector2(-r * 0.25, r * 0.1), mid + Vector2(0, -r * 0.4),
				mid + Vector2(r * 0.25, r * 0.1), mid + Vector2(r * 0.5, -r * 0.2), mid + Vector2(r * 0.5, r * 0.45)])
			var crown: Color = lk["gem"]
			c.draw_colored_polygon(cr, crown)
			c.draw_polyline(cr, _dark(crown, 0.5), 1.5, true)
		_:  # a keyhole
			c.draw_circle(mid + Vector2(0, -r * 0.1), r * 0.26, edge)
			c.draw_colored_polygon(PackedVector2Array([mid + Vector2(-r * 0.12, r * 0.05), mid + Vector2(r * 0.12, r * 0.05), mid + Vector2(r * 0.2, r * 0.6), mid + Vector2(-r * 0.2, r * 0.6)]), edge)


static func _tier_front(c: CanvasItem, body: Rect2, w: float, chest_id: String, lk: Dictionary, line: Color) -> void:
	var cx := body.get_center().x
	var metal: Array = lk["metal"]
	match chest_id:
		"crate":  # steel carrying rings on the sides, like the hoops
			var ring_y := body.position.y + body.size.y * 0.45
			for side in [-1.0, 1.0]:
				var rc := Vector2(cx + w * 0.5 * float(side), ring_y)
				var a0: float = -PI / 2.0 if side > 0.0 else PI / 2.0
				c.draw_arc(rc, w * 0.07, a0, a0 + PI, 10, _dark(metal[2], 0.45), maxf(3.5, w * 0.04), true)
				c.draw_arc(rc, w * 0.07, a0, a0 + PI, 10, metal[1], maxf(2.0, w * 0.022), true)
				_rivet(c, rc, w * 0.02, metal, line)
		"iron":  # steel corner plates
			for sx in [-0.46, 0.46]:
				var plate := Rect2(Vector2(cx + w * float(sx) - w * 0.05, body.end.y - w * 0.18), Vector2(w * 0.1, w * 0.16))
				_paint(c, _rrect(plate, 3.0, 3), plate, metal, _dark(metal[2], 0.4), 1.5, 0.6)
				_rivet(c, plate.get_center(), w * 0.017, metal, line)
		"coffer":  # gold curls between the hoops
			for sx in [-0.17, 0.17]:
				var mid := Vector2(cx + w * float(sx), body.position.y + body.size.y * 0.55)
				c.draw_arc(mid, w * 0.07, 0.4, TAU - 0.4, 12, _dark(metal[2], 0.4), maxf(3.0, w * 0.026), true)
				c.draw_arc(mid, w * 0.07, 0.4, TAU - 0.4, 12, metal[1], maxf(1.5, w * 0.014), true)
		"gilded":  # gold medallions
			for sx in [-0.17, 0.17]:
				var mp := Vector2(cx + w * float(sx), body.position.y + body.size.y * 0.55)
				c.draw_circle(mp, w * 0.058, _dark(metal[2], 0.4))
				c.draw_circle(mp, w * 0.048, metal[1])
				c.draw_circle(mp + Vector2(-w * 0.01, -w * 0.01), w * 0.03, metal[0])
		"vault":  # chain links across the front
			for k in 7:
				var lp := Vector2(body.position.x + w * (0.08 + 0.14 * float(k)), body.position.y + body.size.y * (0.28 + 0.4 * float(k % 2)))
				c.draw_arc(lp, w * 0.03, 0.0, TAU, 10, _dark(metal[2], 0.4), maxf(2.5, w * 0.022), true)
				c.draw_arc(lp, w * 0.03, 0.0, TAU, 10, metal[1], maxf(1.2, w * 0.012), true)


static func _tier_lid(c: CanvasItem, hw: float, lid_h: float, w: float, chest_id: String, lk: Dictionary) -> void:
	var metal: Array = lk["metal"]
	match chest_id:
		"coffer":
			c.draw_arc(Vector2(0, -lid_h * 0.55), w * 0.12, PI, TAU, 12, _dark(metal[2], 0.4), maxf(3.0, w * 0.026), true)
			c.draw_arc(Vector2(0, -lid_h * 0.55), w * 0.12, PI, TAU, 12, metal[1], maxf(1.5, w * 0.014), true)
		"gilded":
			var y := -lid_h * 0.64
			var cr := PackedVector2Array([Vector2(-w * 0.1, y + w * 0.06), Vector2(-w * 0.1, y - w * 0.02), Vector2(-w * 0.05, y + w * 0.02), Vector2(0, y - w * 0.06),
				Vector2(w * 0.05, y + w * 0.02), Vector2(w * 0.1, y - w * 0.02), Vector2(w * 0.1, y + w * 0.06)])
			var top: Color = metal[0]
			c.draw_colored_polygon(cr, top)
			c.draw_polyline(PackedVector2Array([cr[0], cr[1], cr[2], cr[3], cr[4], cr[5], cr[6], cr[0]]), _dark(metal[2], 0.4), 1.5, true)
		"vault":
			var shine: Color = metal[0]
			for k in 3:
				var xx := -w * 0.3 + w * 0.3 * float(k)
				c.draw_line(Vector2(xx, _lid_top(xx, hw, lid_h) + 3.0), Vector2(xx + w * 0.06, -lid_h * 0.2), Color(shine.r, shine.g, shine.b, 0.7), maxf(1.5, w * 0.012))
