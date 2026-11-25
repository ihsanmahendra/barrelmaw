class_name ChestArt
extends RefCounted
## Chests drawn in code (a placeholder look until real chest art exists): five tiers with their own
## wood, bands and lock. draw() works on any CanvasItem whose transform is the identity.

const LOOKS: Dictionary = {
	"crate": {"wood": Color("a8743f"), "dark": Color("6b4a2f"), "band": Color("5a3a22"), "lock": Color("e0c27a"), "glow": Color("ffd9a0")},
	"iron": {"wood": Color("5b7090"), "dark": Color("34425c"), "band": Color("cfd8e6"), "lock": Color("f1f4fa"), "glow": Color("9fd4ff")},
	"coffer": {"wood": Color("7a47b8"), "dark": Color("4c2b78"), "band": Color("d7dbe6"), "lock": Color("f1f4fa"), "glow": Color("d5a8ff")},
	"gilded": {"wood": Color("c98a1c"), "dark": Color("8a5a10"), "band": Color("ffe08a"), "lock": Color("fff3c4"), "glow": Color("ffe08a")},
	"vault": {"wood": Color("1f6f6a"), "dark": Color("123f40"), "band": Color("8fe9dc"), "lock": Color("3de0c8"), "glow": Color("3de0c8")},
}
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


## Draws a chest centered at `center`, `w` wide. open_t 0 is closed, 1 is wide open; t is time for shimmer.
static func draw(c: CanvasItem, center: Vector2, w: float, chest_id: String, open_t: float = 0.0, t: float = 0.0) -> void:
	var lk := look(chest_id)
	var h := w * 0.78
	var body := Rect2(center + Vector2(-w / 2.0, h * 0.02), Vector2(w, h * 0.5))
	var lid_h := h * 0.34
	var hinge := Vector2(center.x, body.position.y)
	# Soft shadow and (for the Vault) a ghostly aura.
	c.draw_set_transform(center + Vector2(0, h * 0.56), 0.0, Vector2(1.0, 0.22))
	c.draw_circle(Vector2.ZERO, w * 0.55, Color(0, 0, 0, 0.22))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if chest_id == "vault":
		var pulse := 0.5 + 0.5 * sin(t * 2.4)
		for i in 4:
			c.draw_circle(center + Vector2(0, h * 0.2), w * (0.62 + 0.1 * i) * (1.0 + 0.04 * pulse), Color(0.24, 0.88, 0.78, 0.07))
	# Light that pours out when open.
	if open_t > 0.02:
		var gl: Color = lk["glow"]
		for i in 9:
			var a := -PI / 2.0 + (float(i) - 4.0) * 0.17
			var len := w * (0.9 + 0.5 * open_t) * (0.8 + 0.2 * sin(t * 3.0 + float(i)))
			var tip := hinge + Vector2(cos(a), sin(a)) * len
			c.draw_colored_polygon(PackedVector2Array([hinge + Vector2(-5, 0), hinge + Vector2(5, 0), tip]), Color(gl.r, gl.g, gl.b, 0.16 * open_t))
		c.draw_circle(hinge + Vector2(0, -h * 0.05), w * 0.42 * open_t, Color(gl.r, gl.g, gl.b, 0.35 * open_t))
	# Body.
	_box(c, body, lk["wood"], int(w * 0.07), lk["dark"], int(maxf(2.0, w * 0.03)))
	for k in 3:
		var y := body.position.y + body.size.y * (0.22 + 0.28 * float(k))
		c.draw_line(Vector2(body.position.x + 6.0, y), Vector2(body.end.x - 6.0, y), Color(0, 0, 0, 0.14), 2.0)
	for sx in [-0.34, 0.34]:
		_box(c, Rect2(Vector2(center.x + w * sx - w * 0.045, body.position.y), Vector2(w * 0.09, body.size.y)), lk["band"], 3)
	# Inside, seen when the lid is up.
	if open_t > 0.1:
		_box(c, Rect2(body.position + Vector2(w * 0.06, -2.0), Vector2(w * 0.88, h * 0.1)), lk["dark"].darkened(0.4), 4)
	# Lid, hinged at the back edge.
	var ang := -open_t * 1.15
	c.draw_set_transform(hinge, ang, Vector2.ONE)
	var lid := Rect2(Vector2(-w / 2.0, -lid_h), Vector2(w, lid_h))
	_box(c, lid, lk["wood"].lightened(0.06), int(w * 0.12), lk["dark"], int(maxf(2.0, w * 0.03)))
	for sx in [-0.34, 0.34]:
		_box(c, Rect2(Vector2(w * sx - w * 0.045, -lid_h), Vector2(w * 0.09, lid_h)), lk["band"], 3)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Lock plate (only while the lid is nearly shut).
	if open_t < 0.35:
		var lock_c := hinge + Vector2(0, 2.0)
		_box(c, Rect2(lock_c + Vector2(-w * 0.07, -w * 0.05), Vector2(w * 0.14, w * 0.17)), lk["lock"], 4, lk["dark"], 2)
		c.draw_circle(lock_c + Vector2(0, w * 0.04), w * 0.022, lk["dark"])
	# Glints on the metal.
	var gl2 := 0.5 + 0.5 * sin(t * 2.0 + w)
	c.draw_circle(body.position + Vector2(w * 0.16, body.size.y * 0.3), w * 0.018, Color(1, 1, 1, 0.5 + 0.3 * gl2))
