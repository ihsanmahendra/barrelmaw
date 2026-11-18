class_name UiKit
extends RefCounted
## Shared look for the interface: colors, wooden button and parchment panel styles, a bold
## font, and the small icons drawn on cards.

const INK := Color("3b2a1e")
const PARCHMENT := Color("f3e2bb")
const PARCHMENT_EDGE := Color("8a5a30")
const WOOD := Color("6b4a2f")
const WOOD_DARK := Color("3a261a")
const GOLD := Color("ffd166")
const CREAM := Color("fff4dc")
const RARITY_COLORS := {
	"common": Color("7d8aa8"),
	"rare": Color("2f9fd0"),
	"epic": Color("8e54d9"),
	"legendary": Color("e0a020"),
}

static var _bold: FontVariation
static var _ui_tex: Dictionary = {}


## A generated UI texture from res://assets/art (ui_<name>.png), or null if it is missing.
static func ui_texture(art_name: String) -> Texture2D:
	if not _ui_tex.has(art_name):
		var path := "res://assets/art/ui_%s.png" % art_name
		_ui_tex[art_name] = load(path) if ResourceLoader.exists(path) else null
	return _ui_tex[art_name]


## The default font, emboldened. Used for titles, numbers and card names.
static func bold_font() -> Font:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = ThemeDB.fallback_font
		_bold.variation_embolden = 0.7
	return _bold


## Chunky wooden button: darker bottom edge for depth, soft shadow, sinks when pressed.
static func plank_style(color: Color, pressed: bool = false) -> StyleBox:
	var tex := ui_texture("plank")
	if tex != null:
		# Generated wooden plank, painted pale so the button color can tint it.
		var st := StyleBoxTexture.new()
		st.texture = tex
		st.texture_margin_left = 28.0
		st.texture_margin_right = 28.0
		st.texture_margin_top = 14.0
		st.texture_margin_bottom = 22.0
		var tint := color.lightened(0.14)
		st.modulate_color = tint.darkened(0.12) if pressed else tint
		st.content_margin_left = 16.0
		st.content_margin_right = 16.0
		st.content_margin_top = 8.0 + (3.0 if pressed else 0.0)
		st.content_margin_bottom = 14.0 - (3.0 if pressed else 0.0)
		return st
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(16)
	s.border_color = color.darkened(0.4)
	s.border_width_left = 2
	s.border_width_right = 2
	s.border_width_top = 2
	s.border_width_bottom = 3 if pressed else 7
	s.shadow_color = Color(0, 0, 0, 0.3)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 3)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10 + (4 if pressed else 0)
	s.content_margin_bottom = 14 - (4 if pressed else 0)
	return s


## Rounded panel with a border, used for chips, hints and pile boxes.
static func panel_style(color: Color, border: Color, border_w: int = 3, radius: int = 18) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border_w)
	s.border_color = border
	s.shadow_color = Color(0, 0, 0, 0.25)
	s.shadow_size = 5
	s.shadow_offset = Vector2(0, 2)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


static func parchment_style() -> StyleBox:
	var tex := ui_texture("parchment")
	if tex != null:
		var st := StyleBoxTexture.new()
		st.texture = tex
		st.texture_margin_left = 48.0
		st.texture_margin_right = 48.0
		st.texture_margin_top = 44.0
		st.texture_margin_bottom = 44.0
		st.content_margin_left = 30.0
		st.content_margin_right = 30.0
		st.content_margin_top = 26.0
		st.content_margin_bottom = 26.0
		return st
	var s := panel_style(PARCHMENT, PARCHMENT_EDGE, 5, 22)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 16
	s.content_margin_bottom = 16
	return s


## Draws a five-point star with its center at c and outer radius r.
static func draw_star(canvas: CanvasItem, c: Vector2, r: float, col: Color, outline: Color = Color(0, 0, 0, 0)) -> void:
	var tex := ui_texture("star")
	if tex != null:
		# Generated glossy gold star. Gold draws as is; other colors tint it (dark = not earned).
		var d := r * 2.4
		var tint := Color.WHITE if col.is_equal_approx(GOLD) else col
		canvas.draw_texture_rect(tex, Rect2(c - Vector2(d, d) / 2.0, Vector2(d, d)), false, tint)
		return
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	canvas.draw_colored_polygon(pts, col)
	if outline.a > 0.0:
		var closed := pts.duplicate()
		closed.append(pts[0])
		canvas.draw_polyline(closed, outline, maxf(1.5, r * 0.12))


## Draws a heart with its center at c and radius r.
static func draw_heart(canvas: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	canvas.draw_circle(c + Vector2(-0.48 * r, -0.25 * r), 0.58 * r, col)
	canvas.draw_circle(c + Vector2(0.48 * r, -0.25 * r), 0.58 * r, col)
	canvas.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-1.03 * r, -0.05 * r), c + Vector2(1.03 * r, -0.05 * r), c + Vector2(0, 1.05 * r)]), col)
	canvas.draw_circle(c + Vector2(-0.55 * r, -0.4 * r), 0.16 * r, Color(1, 1, 1, 0.55))


## Draws the icon that summarizes a card's main effect inside rect.
static func draw_card_icon(c: CanvasItem, rect: Rect2, card: Dictionary) -> void:
	var effects: Array = card["effects"]
	var kinds := {}
	var shape := ""
	var ammo := 0
	var count := 0
	for e in effects:
		kinds[e["kind"]] = true
		if e["kind"] == "shape":
			shape = e["shape"]
		if e["kind"] == "ammo":
			ammo += int(e["n"])
		if e.has("n"):
			count = maxi(count, int(e["n"]))
	var mid := rect.get_center()
	var font := bold_font()
	if shape != "":
		_icon_grid(c, mid + Vector2(-12, 0), minf(rect.size.y - 4.0, 54.0), shape)
		var badge_x := rect.end.x - 6.0
		if kinds.has("wild"):
			PirateArt.draw_cannonball(c, Vector2(badge_x - 18.0, mid.y - 14.0), 9.0, Color("ef476f"))
			PirateArt.draw_cannonball(c, Vector2(badge_x - 8.0, mid.y - 8.0), 9.0, Color("4cc9f0"))
		if ammo > 0:
			_outlined(c, font, Vector2(badge_x - 34.0, mid.y + 22.0), "+%d" % ammo, 20, GOLD)
		if kinds.has("double"):
			_outlined(c, font, Vector2(badge_x - 34.0, mid.y + 22.0), "x2", 20, GOLD)
		return
	if kinds.has("clear_color") or kinds.has("clear_random"):
		PirateArt.draw_barrel(c, mid + Vector2(-14, 0), 40.0, 48.0, Color("ef476f"))
		c.draw_line(mid + Vector2(-26, -12), mid + Vector2(-2, 12), Color("ffffff"), 4.0)
		c.draw_line(mid + Vector2(-2, -12), mid + Vector2(-26, 12), Color("ffffff"), 4.0)
		_outlined(c, font, mid + Vector2(16, 10), "x%d" % count, 26, GOLD)
	elif kinds.has("chaos"):
		var d := Rect2(mid - Vector2(22, 22), Vector2(44, 44))
		c.draw_rect(d, Color("f6ead0"))
		c.draw_rect(d, INK, false, 3.0)
		for p in [Vector2(-12, -12), Vector2(12, -12), Vector2(0, 0), Vector2(-12, 12), Vector2(12, 12)]:
			c.draw_circle(mid + p, 4.5, INK)
	elif kinds.has("wild"):
		PirateArt.draw_cannonball(c, mid + Vector2(-22, 6), 16.0, Color("ef476f"))
		PirateArt.draw_cannonball(c, mid + Vector2(22, 6), 16.0, Color("ffd166"))
		PirateArt.draw_cannonball(c, mid + Vector2(0, -6), 18.0, Color("4cc9f0"))
	elif kinds.has("double"):
		PirateArt.draw_cannonball(c, mid + Vector2(-34, 0), 14.0, Color("ef476f"))
		PirateArt.draw_cannonball(c, mid + Vector2(-12, 0), 14.0, Color("ef476f"))
		_outlined(c, font, mid + Vector2(8, 10), "x2", 28, GOLD)
	elif kinds.has("ammo"):
		PirateArt.draw_cannonball(c, mid + Vector2(-20, 0), 22.0, Color("ef476f"))
		_outlined(c, font, mid + Vector2(8, 12), "+%d" % ammo, 34, GOLD)
		if kinds.has("draw"):
			_card_backs(c, mid + Vector2(40, -12), 2, 0.7)
	elif kinds.has("dup"):
		PirateArt.draw_cannonball(c, mid + Vector2(-8, 4), 20.0, Color("ef476f").darkened(0.15))
		PirateArt.draw_cannonball(c, mid + Vector2(12, -4), 20.0, Color("ef476f"))
	elif kinds.has("add_shooter"):
		PirateArt.draw_cannonball(c, mid + Vector2(-10, 4), 22.0, Color("ef476f"), str(count), 22)
		_outlined(c, font, mid + Vector2(14, -6), "+", 34, GOLD)
	elif kinds.has("recolor_next"):
		PirateArt.draw_cannonball(c, mid + Vector2(-22, 0), 17.0, Color("4cc9f0"))
		c.draw_line(mid + Vector2(-2, 0), mid + Vector2(10, 0), CREAM, 4.0)
		c.draw_colored_polygon(PackedVector2Array([mid + Vector2(8, -7), mid + Vector2(18, 0), mid + Vector2(8, 7)]), CREAM)
		PirateArt.draw_cannonball(c, mid + Vector2(32, 0), 17.0, Color("ef476f"))
	elif kinds.has("skip"):
		PirateArt.draw_cannonball(c, mid + Vector2(-26, 8), 14.0, Color("ef476f"))
		PirateArt.draw_cannonball(c, mid + Vector2(0, 8), 14.0, Color("ffd166"))
		PirateArt.draw_cannonball(c, mid + Vector2(26, 8), 14.0, Color("06d6a0"))
		var arc := PackedVector2Array()
		for i in 9:
			var a := PI + PI * float(i) / 8.0
			arc.append(mid + Vector2(0, 0) + Vector2(cos(a) * 28.0, sin(a) * 16.0))
		c.draw_polyline(arc, GOLD, 4.0)
		c.draw_colored_polygon(PackedVector2Array([mid + Vector2(21, -4), mid + Vector2(33, -6), mid + Vector2(28, 6)]), GOLD)
	elif kinds.has("draw"):
		_card_backs(c, mid + Vector2(-8, 0), maxi(2, count + 1), 1.0)
		_outlined(c, font, mid + Vector2(22, 12), "+%d" % count, 28, GOLD)
	elif kinds.has("extra_play"):
		_card_backs(c, mid + Vector2(-8, 0), 2, 1.0)
		_outlined(c, font, mid + Vector2(20, 12), "+1", 28, GOLD)


static func _outlined(c: CanvasItem, font: Font, pos: Vector2, text: String, size: int, col: Color) -> void:
	c.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 7, Color(0.1, 0.07, 0.05, 0.95))
	c.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## A 5x5 diagram with the cells a shape clears highlighted, and the cannonball at its center.
static func _icon_grid(c: CanvasItem, center: Vector2, total: float, shape: String) -> void:
	var cell := total / 5.0
	var origin := center - Vector2(total, total) / 2.0
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(cell * 0.28))
	for y in 5:
		for x in 5:
			var hit := false
			match shape:
				"row":
					hit = y == 2
				"col":
					hit = x == 2
				"cross":
					hit = x == 2 or y == 2
				"diag":
					hit = absi(x - 2) == absi(y - 2)
				"blast":
					hit = absi(x - 2) <= 1 and absi(y - 2) <= 1
			sb.bg_color = Color("ff8a2b") if hit else Color(0.45, 0.32, 0.2, 0.55)
			c.draw_style_box(sb, Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell)).grow(-1.2))
	PirateArt.draw_cannonball(c, center, cell * 0.46, Color("fff4dc"))


static func _card_backs(c: CanvasItem, center: Vector2, n: int, scale: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(5)
	sb.set_border_width_all(2)
	sb.border_color = CREAM
	for i in n:
		var off := Vector2((i - (n - 1) / 2.0) * 14.0 * scale, -absf(i - (n - 1) / 2.0) * 2.0)
		sb.bg_color = Color("3a6ea5")
		c.draw_style_box(sb, Rect2(center + off - Vector2(15, 20) * scale, Vector2(30, 40) * scale))
