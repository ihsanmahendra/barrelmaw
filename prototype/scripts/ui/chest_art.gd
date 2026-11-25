class_name ChestArt
extends RefCounted
## Chests drawn in code: five tiers with their own wood, metal, lock and treasure. draw() works on any
## CanvasItem whose transform is the identity. (No generated chest art yet; this is the shipped look.)
## open_t 0 is shut, 1 is wide open: the lid swings up and away, the light pours out and a treasure heap
## rises. t is time in seconds for glints and the Vault's wisps.

const LOOKS: Dictionary = {
	"crate": {"wood": Color("a8743f"), "dark": Color("5e3d22"), "metal": Color("6b5440"), "metal_hi": Color("a58968"), "lock": Color("e0c27a"),
		"glow": Color("ffd9a0"), "coin": Color("d08a3c"), "gem": Color("e0a05a")},
	"iron": {"wood": Color("56698a"), "dark": Color("2c3850"), "metal": Color("aab6c8"), "metal_hi": Color("eef3fb"), "lock": Color("dfe6f2"),
		"glow": Color("9fd4ff"), "coin": Color("c9d3e2"), "gem": Color("5db7ff")},
	"coffer": {"wood": Color("7a47b8"), "dark": Color("3f2468"), "metal": Color("cdd2e0"), "metal_hi": Color("ffffff"), "lock": Color("f1f4fa"),
		"glow": Color("d5a8ff"), "coin": Color("f0c75a"), "gem": Color("e05bd8")},
	"gilded": {"wood": Color("c4821a"), "dark": Color("7a4a0c"), "metal": Color("f4cd62"), "metal_hi": Color("fff2b8"), "lock": Color("fff3c4"),
		"glow": Color("ffe08a"), "coin": Color("ffd34d"), "gem": Color("ff5a6e")},
	"vault": {"wood": Color("1c6a68"), "dark": Color("0d3a3c"), "metal": Color("7fdccf"), "metal_hi": Color("d8fff8"), "lock": Color("3de0c8"),
		"glow": Color("3de0c8"), "coin": Color("7ff0e0"), "gem": Color("b27bff")},
}
# Where the treasure sits in the heap: x (-0.5..0.5 of the width), height above the chest rim, radius (of the width).
const HEAP: Array = [[-0.30, 0.02, 0.07], [-0.15, 0.03, 0.07], [0.0, 0.02, 0.07], [0.16, 0.03, 0.07], [0.30, 0.02, 0.07],
	[-0.22, 0.10, 0.065], [-0.07, 0.11, 0.065], [0.09, 0.10, 0.065], [0.24, 0.10, 0.065],
	[-0.14, 0.18, 0.06], [0.02, 0.19, 0.06], [0.16, 0.17, 0.06], [-0.04, 0.26, 0.055]]
static var _sb := StyleBoxFlat.new()


static func look(chest_id: String) -> Dictionary:
	return LOOKS.get(chest_id, LOOKS["crate"])


static func glow_color(chest_id: String) -> Color:
	return look(chest_id)["glow"]


static func _box(c: CanvasItem, rect: Rect2, color: Color, radius: int, border: Color = Color(0, 0, 0, 0), border_w: int = 0) -> void:
	_sb.bg_color = color
	_sb.set_corner_radius_all(radius)
	_sb.set_border_width_all(border_w)
	_sb.border_color = border
	c.draw_style_box(_sb, rect)


## Vertical gradient inside a rectangle (top color to bottom color).
static func _gradient(c: CanvasItem, rect: Rect2, top: Color, bottom: Color) -> void:
	c.draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


static func _glint(c: CanvasItem, p: Vector2, r: float, a: float) -> void:
	var col := Color(1, 1, 1, a)
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r * 0.22, -r * 0.22), p + Vector2(r, 0), p + Vector2(r * 0.22, r * 0.22),
		p + Vector2(0, r), p + Vector2(-r * 0.22, r * 0.22), p + Vector2(-r, 0), p + Vector2(-r * 0.22, -r * 0.22)]), col)


## The lid outline in its own space: bottom edge at y = 0 (width 2 * hw), rising to y = -lid_h along a dome.
static func _lid_points(hw: float, lid_h: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(-hw, 0), Vector2(-hw, -lid_h * 0.42)])
	for i in range(1, 17):
		var u := PI * float(i) / 16.0
		pts.append(Vector2(-hw * cos(u), -lid_h * (0.42 + 0.58 * sin(u))))
	pts.append(Vector2(hw, -lid_h * 0.42))
	pts.append(Vector2(hw, 0))
	return pts


static func _lid_top(x: float, hw: float, lid_h: float) -> float:
	var k := clampf(x / hw, -1.0, 1.0)
	return -lid_h * (0.42 + 0.58 * sqrt(maxf(0.0, 1.0 - k * k)))


## One metal band across the lid, following the dome.
static func _lid_band(c: CanvasItem, x: float, bw: float, hw: float, lid_h: float, lk: Dictionary) -> void:
	var pts := PackedVector2Array([Vector2(x - bw / 2.0, 0)])
	for i in 7:
		var xx := x - bw / 2.0 + bw * float(i) / 6.0
		pts.append(Vector2(xx, _lid_top(xx, hw, lid_h)))
	pts.append(Vector2(x + bw / 2.0, 0))
	c.draw_colored_polygon(pts, lk["metal"])
	c.draw_line(Vector2(x - bw * 0.2, -2.0), Vector2(x - bw * 0.2, _lid_top(x - bw * 0.2, hw, lid_h) + 4.0), lk["metal_hi"], maxf(1.0, bw * 0.12))


static func _rivets(c: CanvasItem, x: float, y0: float, y1: float, n: int, r: float, lk: Dictionary) -> void:
	for i in n:
		var y := lerpf(y0, y1, (float(i) + 0.5) / float(n))
		c.draw_circle(Vector2(x, y), r, lk["dark"])
		c.draw_circle(Vector2(x - r * 0.2, y - r * 0.2), r * 0.62, lk["metal_hi"])


## Coins and gems heaped inside the chest, rising with open_t.
static func _draw_heap(c: CanvasItem, body: Rect2, w: float, open_t: float, t: float, lk: Dictionary, chest_id: String) -> void:
	var rim_y := body.position.y + 4.0
	var rise := clampf((open_t - 0.15) / 0.6, 0.0, 1.0)
	if rise <= 0.0:
		return
	var cx := body.get_center().x
	# Dark mound the heap rests on.
	var mound := PackedVector2Array([Vector2(cx - w * 0.42, rim_y + 6.0), Vector2(cx - w * 0.36, rim_y - w * 0.07 * rise),
		Vector2(cx, rim_y - w * 0.15 * rise), Vector2(cx + w * 0.36, rim_y - w * 0.07 * rise), Vector2(cx + w * 0.42, rim_y + 6.0)])
	c.draw_colored_polygon(mound, lk["coin"].darkened(0.45))
	for i in HEAP.size():
		var h: Array = HEAP[i]
		var p := Vector2(cx + w * float(h[0]), rim_y - w * float(h[1]) * 0.75 * rise)
		var r := w * float(h[2]) * (0.6 + 0.4 * rise)
		if i % 5 == 2:  # a gem
			var g: Color = lk["gem"]
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r * 1.1), p + Vector2(r * 0.9, 0), p + Vector2(0, r * 1.1), p + Vector2(-r * 0.9, 0)]), g)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r * 1.1), p + Vector2(r * 0.9, 0), p + Vector2(0, -r * 0.1)]), g.lightened(0.45))
		else:
			c.draw_circle(p, r, lk["coin"].darkened(0.3))
			c.draw_circle(p, r * 0.82, lk["coin"])
			c.draw_arc(p + Vector2(-r * 0.1, -r * 0.1), r * 0.55, PI * 1.05, PI * 1.75, 6, Color(1, 1, 1, 0.55), maxf(1.0, r * 0.18))
	var tw := 0.5 + 0.5 * sin(t * 3.0)
	_glint(c, Vector2(cx - w * 0.12, rim_y - w * 0.2 * rise), w * 0.05 * rise, 0.5 + 0.5 * tw)
	_glint(c, Vector2(cx + w * 0.2, rim_y - w * 0.12 * rise), w * 0.04 * rise, 1.0 - 0.5 * tw)


## Draws a chest centered at `center`, `w` wide.
static func draw(c: CanvasItem, center: Vector2, w: float, chest_id: String, open_t: float = 0.0, t: float = 0.0) -> void:
	var lk := look(chest_id)
	var h := w * 0.82
	var body_h := h * 0.5
	var body := Rect2(Vector2(center.x - w * 0.5, center.y + h * 0.04), Vector2(w, body_h))
	var hinge_y := body.position.y
	var lid_h := h * 0.4
	var gl: Color = lk["glow"]
	var hw := w * 0.515
	# Ground shadow.
	c.draw_set_transform(Vector2(center.x, body.end.y + 3.0), 0.0, Vector2(1.0, 0.2))
	c.draw_circle(Vector2.ZERO, w * 0.58, Color(0, 0, 0, 0.26))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Aura: soft for every chest, ghostly and pulsing for the Vault, strong when open.
	var aura := 0.06 + 0.22 * open_t
	if chest_id == "vault":
		aura += 0.07 + 0.05 * sin(t * 2.4)
	for i in 4:
		c.draw_circle(Vector2(center.x, body.position.y), w * (0.55 + 0.13 * float(i)), Color(gl.r, gl.g, gl.b, aura * 0.35))
	# Light rays when open.
	if open_t > 0.05:
		var origin := Vector2(center.x, hinge_y - 2.0)
		for i in 11:
			var a := -PI / 2.0 + (float(i) - 5.0) * 0.15
			var length := w * (0.85 + 0.65 * open_t) * (0.8 + 0.2 * sin(t * 3.0 + float(i) * 1.7))
			var tip := origin + Vector2(cos(a), sin(a)) * length
			var side := Vector2(-sin(a), cos(a)) * (w * 0.02)
			c.draw_colored_polygon(PackedVector2Array([origin + side, origin - side, tip - side * 3.0, tip + side * 3.0]), Color(gl.r, gl.g, gl.b, 0.17 * open_t))
	# The lid, opened past upright: its inside shows above the back of the chest, behind the heap.
	var ang := open_t * PI * 0.76
	var fore := cos(ang)
	if fore < 0.0:
		c.draw_set_transform(Vector2(center.x, hinge_y - 4.0), 0.0, Vector2(1.0, -fore * 1.25))
		var inner := _lid_points(hw * 0.96, lid_h)
		c.draw_colored_polygon(_lid_points(hw, lid_h), lk["dark"])
		c.draw_colored_polygon(inner, lk["wood"].lightened(0.05))
		c.draw_colored_polygon(_lid_points(hw * 0.8, lid_h * 0.8), lk["wood"].darkened(0.35))  # the padded lining
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if open_t > 0.0:
		_draw_heap(c, body, w, open_t, t, lk, chest_id)
	# Body front.
	_box(c, body, lk["wood"], int(w * 0.045), lk["dark"], int(maxf(2.0, w * 0.028)))
	var inner_body := body.grow(-w * 0.03)
	_gradient(c, inner_body, Color(1, 1, 1, 0.16), Color(0, 0, 0, 0.3))
	for k in 3:  # plank seams
		var y := body.position.y + body_h * (0.27 + 0.27 * float(k))
		c.draw_line(Vector2(body.position.x + 5.0, y), Vector2(body.end.x - 5.0, y), Color(0, 0, 0, 0.28), maxf(1.5, w * 0.012))
		c.draw_line(Vector2(body.position.x + 5.0, y + 2.0), Vector2(body.end.x - 5.0, y + 2.0), Color(1, 1, 1, 0.1), 1.0)
	for k in 5:  # a little grain
		var gx := body.position.x + w * (0.12 + 0.19 * float(k))
		c.draw_line(Vector2(gx, body.position.y + body_h * 0.34), Vector2(gx + w * 0.05, body.position.y + body_h * 0.4), Color(0, 0, 0, 0.14), 1.5)
	# Metal: two bands, a top rim, corner plates.
	var bw := w * 0.095
	for sx in [-0.34, 0.34]:
		var bx: float = center.x + w * float(sx) - bw / 2.0
		_box(c, Rect2(Vector2(bx, body.position.y), Vector2(bw, body_h)), lk["metal"], 3, lk["dark"], 1)
		c.draw_line(Vector2(bx + bw * 0.28, body.position.y + 3.0), Vector2(bx + bw * 0.28, body.end.y - 3.0), lk["metal_hi"], maxf(1.0, bw * 0.12))
		_rivets(c, bx + bw / 2.0, body.position.y + 6.0, body.end.y - 6.0, 3, bw * 0.17, lk)
	_box(c, Rect2(body.position + Vector2(0, -2.0), Vector2(w, w * 0.05)), lk["metal"], 3, lk["dark"], 1)
	_box(c, Rect2(Vector2(body.position.x, body.end.y - w * 0.05), Vector2(w, w * 0.05)), lk["dark"], 3)
	# Tier details on the front.
	_tier_front(c, body, w, chest_id, lk, t)
	# The lid, closed or swinging up: its front face gets shorter as it tips back.
	if fore >= 0.0:
		c.draw_set_transform(Vector2(center.x, hinge_y), 0.0, Vector2(1.0, maxf(fore, 0.04)))
		var pts := _lid_points(hw, lid_h)
		c.draw_colored_polygon(pts, lk["dark"])
		c.draw_colored_polygon(_lid_points(hw - w * 0.02, lid_h - 3.0), lk["wood"].lightened(0.05))
		# Highlight along the dome and plank seams.
		c.draw_colored_polygon(_lid_points(hw - w * 0.05, lid_h * 0.55), Color(1, 1, 1, 0.1))
		for k in 3:
			var sx2 := -hw + hw * 2.0 * (float(k) + 1.0) / 4.0
			c.draw_line(Vector2(sx2, -3.0), Vector2(sx2, _lid_top(sx2, hw, lid_h) + 5.0), Color(0, 0, 0, 0.2), 1.5)
		for sx in [-0.34, 0.34]:
			_lid_band(c, w * float(sx), bw, hw, lid_h, lk)
		_tier_lid(c, hw, lid_h, w, chest_id, lk)
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# Lock plate on the seam while the lid is shut.
		if open_t < 0.3:
			_lock(c, Vector2(center.x, hinge_y + 2.0), w, chest_id, lk, t)
	# Glints on the metal.
	var tw := 0.5 + 0.5 * sin(t * 2.2 + w)
	_glint(c, Vector2(center.x - w * 0.34, body.position.y + body_h * 0.28), w * 0.035, 0.45 + 0.4 * tw)
	if chest_id == "vault":
		for i in 5:  # wisps rising off the Vault
			var phase := fposmod(t * 0.35 + float(i) * 0.2, 1.0)
			var wp := Vector2(center.x + w * (-0.4 + 0.2 * float(i)) + sin(t * 2.0 + float(i)) * 6.0, body.position.y - lid_h * 0.2 - phase * h * 0.7)
			c.draw_circle(wp, w * 0.035 * (1.0 - phase), Color(0.5, 1.0, 0.92, 0.45 * (1.0 - phase)))


static func _lock(c: CanvasItem, p: Vector2, w: float, chest_id: String, lk: Dictionary, t: float) -> void:
	var r := w * 0.085
	match chest_id:
		"vault":
			var pulse := 0.6 + 0.4 * sin(t * 3.0)
			c.draw_circle(p + Vector2(0, r * 0.3), r * 1.9, Color(0.24, 0.88, 0.78, 0.18 * pulse))
			c.draw_circle(p + Vector2(0, r * 0.3), r * 1.15, lk["dark"])
			c.draw_circle(p + Vector2(0, r * 0.3), r, lk["lock"])
			c.draw_circle(p + Vector2(-r * 0.35, r * 0.15), r * 0.22, lk["dark"])  # skull eyes
			c.draw_circle(p + Vector2(r * 0.35, r * 0.15), r * 0.22, lk["dark"])
			c.draw_rect(Rect2(p + Vector2(-r * 0.22, r * 0.55), Vector2(r * 0.44, r * 0.36)), lk["dark"])
		"coffer":
			_box(c, Rect2(p + Vector2(-r * 0.9, -r * 0.6), Vector2(r * 1.8, r * 2.1)), lk["lock"], 5, lk["dark"], 2)
			var g: Color = lk["gem"]
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r * 0.2), p + Vector2(r * 0.6, r * 0.5), p + Vector2(0, r * 1.2), p + Vector2(-r * 0.6, r * 0.5)]), g)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r * 0.2), p + Vector2(r * 0.6, r * 0.5), p + Vector2(0, r * 0.4)]), g.lightened(0.5))
		"gilded":
			_box(c, Rect2(p + Vector2(-r * 0.95, -r * 0.65), Vector2(r * 1.9, r * 2.2)), lk["lock"], 6, lk["dark"], 2)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.6, r * 0.9), p + Vector2(-r * 0.6, r * 0.1), p + Vector2(-r * 0.3, r * 0.45), p + Vector2(0, -r * 0.1),
				p + Vector2(r * 0.3, r * 0.45), p + Vector2(r * 0.6, r * 0.1), p + Vector2(r * 0.6, r * 0.9)]), lk["gem"])  # a crown
		_:
			_box(c, Rect2(p + Vector2(-r * 0.8, -r * 0.55), Vector2(r * 1.6, r * 1.9)), lk["lock"], 4, lk["dark"], 2)
			c.draw_circle(p + Vector2(0, r * 0.3), r * 0.28, lk["dark"])
			c.draw_rect(Rect2(p + Vector2(-r * 0.09, r * 0.35), Vector2(r * 0.18, r * 0.55)), lk["dark"])


static func _tier_front(c: CanvasItem, body: Rect2, w: float, chest_id: String, lk: Dictionary, t: float) -> void:
	var cx := body.get_center().x
	match chest_id:
		"crate":  # rope slung round the sides
			var rope_y := body.position.y + body.size.y * 0.5
			c.draw_arc(Vector2(cx - w * 0.5, rope_y), body.size.y * 0.5, -PI / 2.0, PI / 2.0, 10, Color("d9c08a"), maxf(2.5, w * 0.03))  # bulges into the body
			c.draw_arc(Vector2(cx + w * 0.5, rope_y), body.size.y * 0.5, PI / 2.0, PI * 1.5, 10, Color("d9c08a"), maxf(2.5, w * 0.03))
			_box(c, Rect2(Vector2(cx - w * 0.07, body.position.y + body.size.y * 0.3), Vector2(w * 0.14, w * 0.18)), lk["lock"], 5, lk["dark"], 2)
		"iron":  # corner plates
			for sx in [-0.46, 0.46]:
				_box(c, Rect2(Vector2(cx + w * float(sx) - w * 0.045, body.end.y - w * 0.16), Vector2(w * 0.09, w * 0.14)), lk["metal"], 3, lk["dark"], 1)
		"coffer":  # silver curls
			for sx in [-0.17, 0.17]:
				c.draw_arc(Vector2(cx + w * float(sx), body.position.y + body.size.y * 0.55), w * 0.07, 0.4, TAU - 0.4, 12, lk["metal"], maxf(2.0, w * 0.018))
		"gilded":  # gold medallions
			for sx in [-0.17, 0.17]:
				c.draw_circle(Vector2(cx + w * float(sx), body.position.y + body.size.y * 0.55), w * 0.05, lk["metal_hi"])
				c.draw_circle(Vector2(cx + w * float(sx), body.position.y + body.size.y * 0.55), w * 0.035, lk["metal"])
		"vault":  # chains across the front
			for k in 7:
				var x0 := body.position.x + w * (0.08 + 0.14 * float(k))
				var y0 := body.position.y + body.size.y * (0.28 + 0.4 * float(k % 2))
				c.draw_set_transform(Vector2(x0, y0), 0.0, Vector2.ONE)
				c.draw_arc(Vector2.ZERO, w * 0.025, 0.0, TAU, 8, lk["metal"], maxf(1.5, w * 0.012))
				c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _tier_lid(c: CanvasItem, hw: float, lid_h: float, w: float, chest_id: String, lk: Dictionary) -> void:
	match chest_id:
		"coffer":
			c.draw_arc(Vector2(0, -lid_h * 0.55), w * 0.12, PI, TAU, 12, lk["metal"], maxf(2.0, w * 0.018))
			c.draw_arc(Vector2(0, -lid_h * 0.55), w * 0.07, PI, TAU, 12, lk["metal"], maxf(1.5, w * 0.012))
		"gilded":
			var y := -lid_h * 0.62
			c.draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.1, y + w * 0.06), Vector2(-w * 0.1, y - w * 0.02), Vector2(-w * 0.05, y + w * 0.02), Vector2(0, y - w * 0.06),
				Vector2(w * 0.05, y + w * 0.02), Vector2(w * 0.1, y - w * 0.02), Vector2(w * 0.1, y + w * 0.06)]), lk["metal_hi"])
		"vault":
			for k in 3:
				var xx := -w * 0.3 + w * 0.3 * float(k)
				c.draw_line(Vector2(xx, _lid_top(xx, hw, lid_h) + 3.0), Vector2(xx + w * 0.06, -lid_h * 0.2), lk["metal"], maxf(1.5, w * 0.012))
		"iron":
			for sx in [-0.17, 0.17]:
				_rivets(c, w * float(sx), -lid_h * 0.55, -lid_h * 0.2, 2, w * 0.016, lk)
