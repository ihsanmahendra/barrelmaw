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
	"transcended": Color("3de0c8"),
}


## Slowly shifting aurora color (teal, violet, gold) for Transcended cards. t is time in seconds.
static func aurora(t: float) -> Color:
	return Color.from_hsv(fposmod(0.52 + 0.22 * sin(t * 0.8) + 0.08 * sin(t * 1.9), 1.0), 0.5, 1.0)

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
		st.content_margin_top = 34.0  # the curled edges are 44 units deep; keep text off them
		st.content_margin_bottom = 40.0
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
	CardArt.draw(c, rect, card)
