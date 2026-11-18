class_name PirateArt
extends RefCounted
## Procedural drawing helpers for the pirate, his cannon and the color barrels.
## All coordinates for the pirate are in "pirate units" (about 125 tall); the caller picks a scale.

const CANNON_ANGLE: float = -0.62  # radians, pointing up and to the right
const BARREL_LENGTH: float = 54.0

static var _sb := StyleBoxFlat.new()
static var _tex_cache: Dictionary = {}
## Multiplies the pirate's colors; dimmer and bluer in night stages.
static var night_tint: Color = Color.WHITE

# Generated art (SpriteCook) lives in res://assets/art. If a file is missing the drawn
# vector versions below are used instead, so the game always renders.
const PIRATE_ASPECT: float = 873.0 / 985.0  # width / height of pirate.png
const PIRATE_MUZZLE_UV: Vector2 = Vector2(0.9416, 0.4112)  # cannon opening inside pirate.png
const PIRATE_LOAD_UV: Vector2 = Vector2(0.667, 0.553)  # where a cannonball drops in
const BARREL_ASPECT: float = 210.0 / 256.0
# Barrels are baked per game color into one atlas (design/art-source/make_barrels.py). Same order as there.
const BARREL_ATLAS_COLORS: Array = ["ef476f", "f78c4a", "ffd166", "06d6a0", "4cc9f0", "9b5de5", "3d405b", "f8f9fa", "a47148", "ff9ecb"]
const BARREL_TILE: Vector2 = Vector2(210.0, 256.0)


static func _tex(art_name: String) -> Texture2D:
	if not _tex_cache.has(art_name):
		var path := "res://assets/art/%s.png" % art_name
		_tex_cache[art_name] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[art_name]


## Screen rectangle of the pirate sprite for a given feet position and scale.
static func _pirate_rect(origin: Vector2, s: float) -> Rect2:
	var h := 124.0 * s
	var w := h * PIRATE_ASPECT
	return Rect2(origin + Vector2(-0.2 * w, -h + 0.02 * h), Vector2(w, h))


## Transform that leans the pirate about his feet (origin) at time t.
static func lean_transform(origin: Vector2, t: float) -> Transform2D:
	return Transform2D(ShipMotion.lean(t), origin) * Transform2D(0.0, -origin)


## Draws the pirate with feet at origin. recoil (0..1) pushes the cannon back; t is time in seconds.
## base is the transform already active on the canvas (the ship's rocking); he leans on top of it.
## shout swaps in the face he pulls while firing; grin (a big hit landed) wins over shout.
static func draw_pirate(c: CanvasItem, origin: Vector2, s: float, t: float, recoil: float, base: Transform2D = Transform2D.IDENTITY, shout: bool = false, grin: bool = false) -> void:
	var tex := _tex("pirate")
	if grin and _tex("pirate_grin") != null:
		tex = _tex("pirate_grin")  # squinting eye, wide toothy grin with a gold tooth
	elif shout and _tex("pirate_fire") != null:
		tex = _tex("pirate_fire")  # mouth open, one eye wide
	if tex == null:
		_draw_pirate_vector(c, origin, s, t, recoil)
		c.draw_set_transform_matrix(base)
		return
	c.draw_set_transform_matrix(base * Transform2D(Vector2(s, 0.0), Vector2(0.0, s * 0.28), origin + Vector2(14.0, 0.0) * s))
	c.draw_circle(Vector2.ZERO, 52.0, Color(0, 0, 0, 0.22))
	c.draw_set_transform_matrix(base * lean_transform(origin, t))
	var rect := _pirate_rect(origin, s)
	var breathe := 1.0 + 0.012 * sin(t * 3.0)
	rect.position.y += rect.size.y * (1.0 - breathe)
	rect.size.y *= breathe
	rect.position += Vector2(-1.0, 0.55).normalized() * recoil * 7.0 * s
	c.draw_texture_rect(tex, rect, false, night_tint)
	c.draw_set_transform_matrix(base)


## Comic speech bubble above the pirate's head with a shouted word. life goes 1 -> 0 over the shout:
## it pops in at the start and fades near the end.
static func draw_shout_bubble(c: CanvasItem, origin: Vector2, s: float, life: float, text: String, base: Transform2D = Transform2D.IDENTITY, color: Color = Color(0.84, 0.16, 0.22)) -> void:
	var rect := _pirate_rect(origin, s)
	var head := rect.position + Vector2(0.45 * rect.size.x, 0.14 * rect.size.y)
	var pop := 1.0 + 0.35 * clampf((life - 0.8) / 0.2, 0.0, 1.0)
	var alpha := clampf(life * 3.0, 0.0, 1.0)
	var font := UiKit.bold_font()
	var fs := int(22.0 * s)
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var size := Vector2(tw + 26.0 * s, 38.0 * s)
	var center := head + Vector2(-8.0 * s, -52.0 * s)
	var m := Transform2D(0.0, center) * Transform2D(Vector2(pop, 0.0), Vector2(0.0, pop), Vector2.ZERO)
	c.draw_set_transform_matrix(base * m)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.97, 0.88, alpha)
	sb.set_corner_radius_all(int(16.0 * s))
	sb.set_border_width_all(3)
	sb.border_color = Color(0.23, 0.16, 0.12, alpha)
	c.draw_style_box(sb, Rect2(-size / 2.0, size))
	# Tail pointing down at the head.
	c.draw_colored_polygon(PackedVector2Array([Vector2(-6.0 * s, size.y / 2.0 - 2.0), Vector2(10.0 * s, size.y / 2.0 - 2.0), Vector2(4.0 * s, size.y / 2.0 + 14.0 * s)]), Color(1.0, 0.97, 0.88, alpha))
	c.draw_polyline(PackedVector2Array([Vector2(-6.0 * s, size.y / 2.0), Vector2(4.0 * s, size.y / 2.0 + 14.0 * s), Vector2(10.0 * s, size.y / 2.0)]), Color(0.23, 0.16, 0.12, alpha), 3.0)
	var pos := Vector2(-tw / 2.0, fs * 0.36)
	c.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(1, 1, 1, alpha))
	c.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(color.r, color.g, color.b, alpha))
	c.draw_set_transform_matrix(base)


## Where cannonballs leave from, in the same space as origin.
static func muzzle(origin: Vector2, s: float, recoil: float = 0.0) -> Vector2:
	if _tex("pirate") == null:
		return _muzzle_vector(origin, s, recoil)
	var rect := _pirate_rect(origin, s)
	return rect.position + PIRATE_MUZZLE_UV * rect.size + Vector2(-1.0, 0.55).normalized() * recoil * 7.0 * s


## Where a cannonball is dropped into the cannon, same space as origin.
static func loading_point(origin: Vector2, s: float) -> Vector2:
	if _tex("pirate") == null:
		return _loading_point_vector(origin, s)
	var rect := _pirate_rect(origin, s)
	return rect.position + PIRATE_LOAD_UV * rect.size


## A colored barrel centered at center, fitted into w by h. Optional number on a plaque.
static func draw_barrel(c: CanvasItem, center: Vector2, w: float, h: float, col: Color, number: String = "", font_size: int = 20) -> void:
	var atlas := _tex("barrel_atlas")
	var slot := BARREL_ATLAS_COLORS.find(col.to_html(false))
	if atlas != null and slot >= 0:
		var dh2 := minf(h, w / BARREL_ASPECT)
		var sz := Vector2(dh2 * BARREL_ASPECT, dh2)
		var src := Rect2(Vector2(float(slot % 5), float(slot / 5)) * BARREL_TILE, BARREL_TILE)
		c.draw_texture_rect_region(atlas, Rect2(center - sz / 2.0, sz), src)
		if number != "":
			_barrel_plaque(c, center, w, number, font_size)
		return
	var tex := _tex("barrel")
	if tex == null:
		_draw_barrel_vector(c, center, w, h, col, number, font_size)
		return
	var dh := minf(h, w / BARREL_ASPECT)
	var size := Vector2(dh * BARREL_ASPECT, dh)
	c.draw_texture_rect(tex, Rect2(center - size / 2.0, size), false, col.lightened(0.06))
	if number != "":
		_barrel_plaque(c, center, w, number, font_size)


## Round parchment plaque with a number, drawn on a barrel.
static func _barrel_plaque(c: CanvasItem, center: Vector2, w: float, number: String, font_size: int) -> void:
	c.draw_circle(center, w * 0.27, Color("f6ead0"))
	c.draw_arc(center, w * 0.27, 0.0, TAU, 20, Color("5a3a22"), 2.0)
	var font := ThemeDB.fallback_font
	var tw := font.get_string_size(number, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
	c.draw_string(font, center + Vector2(-tw / 2.0, font_size * 0.36), number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("3b2a1e"))


## A cannonball of the given color with an optional number on top.
static func draw_cannonball(c: CanvasItem, center: Vector2, r: float, col: Color, number: String = "", font_size: int = 20) -> void:
	var tex := _tex("cannonball")
	if tex == null:
		_draw_cannonball_vector(c, center, r, col, number, font_size)
		return
	c.draw_circle(center + Vector2(0, r * 0.12), r * 0.98, Color(0.08, 0.08, 0.12, 0.3))  # soft shadow
	var d := r * 2.08
	c.draw_texture_rect(tex, Rect2(center - Vector2(d, d) / 2.0, Vector2(d, d)), false, col.lightened(0.04))
	if number != "":
		var font := ThemeDB.fallback_font
		var tw := font.get_string_size(number, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
		var pos := center + Vector2(-tw / 2.0, font_size * 0.36)
		c.draw_string_outline(font, pos, number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color(0.1, 0.07, 0.05, 0.95))
		c.draw_string(font, pos, number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("fff4dc"))


## Draws the pirate with feet at origin. recoil (0..1) pushes the cannon back; t is time in seconds.
static func _draw_pirate_vector(c: CanvasItem, origin: Vector2, s: float, t: float, recoil: float) -> void:
	var bob := sin(t * 3.0) * 1.6
	c.draw_set_transform(origin, 0.0, Vector2(s, s))
	# Ground shadow.
	c.draw_set_transform(origin + Vector2(10.0, 0.0) * s, 0.0, Vector2(s, s * 0.28))
	c.draw_circle(Vector2.ZERO, 46.0, Color(0, 0, 0, 0.22))
	c.draw_set_transform(origin, 0.0, Vector2(s, s))
	# Legs and boots.
	c.draw_rect(Rect2(-14, -30, 10, 24), Color("3b3b58"))
	c.draw_rect(Rect2(4, -30, 10, 24), Color("3b3b58"))
	c.draw_rect(Rect2(-17, -9, 15, 9), Color("2a1a14"))
	c.draw_rect(Rect2(3, -9, 15, 9), Color("2a1a14"))
	# Striped shirt.
	for i in 6:
		var col := Color("d62839") if i % 2 == 0 else Color("f6ead0")
		c.draw_rect(Rect2(-18, -72 + bob + i * 7.4, 36, 7.4), col)
	c.draw_rect(Rect2(-18, -34 + bob, 36, 6), Color("5a3a22"))
	c.draw_rect(Rect2(-4, -35 + bob, 8, 8), Color("f2c94c"))
	# Head, beard, face.
	var hy := -88.0 + bob
	c.draw_circle(Vector2(0, hy), 15.0, Color("f2c4a0"))
	c.draw_colored_polygon(PackedVector2Array([
		Vector2(-13, hy + 4), Vector2(13, hy + 4), Vector2(11, hy + 17), Vector2(0, hy + 24), Vector2(-11, hy + 17)]), Color("2b1d14"))
	c.draw_line(Vector2(-4, hy + 8), Vector2(5, hy + 8), Color("f6ead0"), 2.0)  # grin
	c.draw_circle(Vector2(8, hy + 0.5), 3.4, Color.WHITE)
	c.draw_circle(Vector2(8.8, hy + 0.5), 1.6, Color("1b1b2a"))
	c.draw_circle(Vector2(-6, hy + 0.5), 4.8, Color("1b1b2a"))  # eye patch
	c.draw_line(Vector2(-15, hy - 9), Vector2(14, hy - 3), Color("1b1b2a"), 2.0)  # patch strap
	# Tricorn hat with skull.
	c.draw_colored_polygon(PackedVector2Array([
		Vector2(-28, hy - 9), Vector2(0, hy - 36), Vector2(28, hy - 9), Vector2(17, hy - 7), Vector2(0, hy - 16), Vector2(-17, hy - 7)]), Color("1b1b2a"))
	c.draw_line(Vector2(-22, hy - 10), Vector2(22, hy - 10), Color("f2c94c"), 2.0)
	c.draw_circle(Vector2(0, hy - 22), 4.2, Color("f6ead0"))
	c.draw_line(Vector2(-6, hy - 16), Vector2(6, hy - 28), Color("f6ead0"), 1.6)
	c.draw_line(Vector2(6, hy - 16), Vector2(-6, hy - 28), Color("f6ead0"), 1.6)
	# Cannon: carriage, wheel, barrel.
	var base := Vector2(46, -44)
	c.draw_colored_polygon(PackedVector2Array([Vector2(28, -36), Vector2(64, -36), Vector2(58, -22), Vector2(34, -22)]), Color("6b4423"))
	c.draw_set_transform(origin + base * s + Vector2(cos(CANNON_ANGLE), sin(CANNON_ANGLE)) * (-recoil * 9.0 * s), CANNON_ANGLE, Vector2(s, s))
	c.draw_rect(Rect2(-14, -10, BARREL_LENGTH + 4, 20), Color("2e3440"))
	c.draw_rect(Rect2(-14, -10, 8, 20), Color("3b4252"))
	c.draw_rect(Rect2(BARREL_LENGTH - 10, -12, 14, 24), Color("4c566a"))
	c.draw_rect(Rect2(BARREL_LENGTH + 2, -8, 3, 16), Color("0d0f14"))
	c.draw_line(Vector2(-10, -6), Vector2(BARREL_LENGTH - 12, -6), Color("6b7488"), 2.0)
	c.draw_set_transform(origin, 0.0, Vector2(s, s))
	var wheel := Vector2(46, -20)
	c.draw_circle(wheel, 16.0, Color("5a3a22"))
	c.draw_circle(wheel, 12.5, Color("8a5a30"))
	for k in 6:
		var a := float(k) / 6.0 * PI
		c.draw_line(wheel - Vector2(cos(a), sin(a)) * 12.0, wheel + Vector2(cos(a), sin(a)) * 12.0, Color("5a3a22"), 2.0)
	c.draw_circle(wheel, 3.5, Color("f2c94c"))
	# Arm reaching for the cannon.
	var shoulder := Vector2(15, -64 + bob)
	var hand := Vector2(40, -52)
	c.draw_line(shoulder, hand, Color("d62839"), 9.0)
	c.draw_circle(hand, 5.5, Color("f2c4a0"))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Where cannonballs (barrels) leave from, in the same space as origin.
static func _muzzle_vector(origin: Vector2, s: float, recoil: float = 0.0) -> Vector2:
	var dir := Vector2(cos(CANNON_ANGLE), sin(CANNON_ANGLE))
	return origin + (Vector2(46, -44) + dir * (BARREL_LENGTH + 4.0 - recoil * 9.0)) * s


## Where a barrel is dropped into the cannon (the barrel's rear), same space as origin.
static func _loading_point_vector(origin: Vector2, s: float) -> Vector2:
	return origin + Vector2(46, -44) * s


## A colored barrel centered at center, w wide and h tall. Optional number on a plaque.
static func _draw_barrel_vector(c: CanvasItem, center: Vector2, w: float, h: float, col: Color, number: String = "", font_size: int = 20) -> void:
	var rect := Rect2(center - Vector2(w, h) / 2.0, Vector2(w, h))
	_sb.bg_color = col
	_sb.set_corner_radius_all(int(w * 0.3))
	_sb.set_border_width_all(2)
	_sb.border_color = col.darkened(0.5)
	c.draw_style_box(_sb, rect)
	var dark := col.darkened(0.35)
	dark.a = 0.45
	c.draw_line(Vector2(rect.position.x + w * 0.33, rect.position.y + h * 0.14), Vector2(rect.position.x + w * 0.33, rect.end.y - h * 0.14), dark, 1.5)
	c.draw_line(Vector2(rect.position.x + w * 0.67, rect.position.y + h * 0.14), Vector2(rect.position.x + w * 0.67, rect.end.y - h * 0.14), dark, 1.5)
	var shine := Color(1, 1, 1, 0.22)
	c.draw_rect(Rect2(rect.position.x + w * 0.12, rect.position.y + h * 0.16, w * 0.1, h * 0.68), shine)
	for yf in [0.2, 0.74]:
		c.draw_rect(Rect2(rect.position.x + 1.0, rect.position.y + h * yf, w - 2.0, h * 0.09), Color("464a57"))
		c.draw_rect(Rect2(rect.position.x + 1.0, rect.position.y + h * yf, w - 2.0, h * 0.025), Color("8d93a5"))
	if number != "":
		c.draw_circle(center, w * 0.27, Color("f6ead0"))
		c.draw_arc(center, w * 0.27, 0.0, TAU, 20, Color("5a3a22"), 2.0)
		var font := ThemeDB.fallback_font
		var tw := font.get_string_size(number, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
		c.draw_string(font, center + Vector2(-tw / 2.0, font_size * 0.36), number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("3b2a1e"))


## A cannonball of the given color: dark iron rim, glossy highlight, optional number on top.
static func _draw_cannonball_vector(c: CanvasItem, center: Vector2, r: float, col: Color, number: String = "", font_size: int = 20) -> void:
	c.draw_circle(center + Vector2(0, r * 0.08), r, Color(0.08, 0.08, 0.12, 0.35))  # soft shadow
	c.draw_circle(center, r, col.darkened(0.6))
	c.draw_circle(center, r * 0.9, col)
	c.draw_circle(center + Vector2(r * 0.18, r * 0.2), r * 0.62, col.darkened(0.18))
	c.draw_circle(center + Vector2(-r * 0.32, -r * 0.34), r * 0.3, Color(1, 1, 1, 0.34))
	c.draw_circle(center + Vector2(-r * 0.36, -r * 0.4), r * 0.13, Color(1, 1, 1, 0.7))
	if number != "":
		var font := ThemeDB.fallback_font
		var tw := font.get_string_size(number, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
		var pos := center + Vector2(-tw / 2.0, font_size * 0.36)
		c.draw_string_outline(font, pos, number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color(0.1, 0.07, 0.05, 0.95))
		c.draw_string(font, pos, number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("fff4dc"))
