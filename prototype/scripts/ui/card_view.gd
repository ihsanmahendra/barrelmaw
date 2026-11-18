class_name CardView
extends Button
## A playing card: rarity ribbon with the name, an icon showing what it does, and short text.
## Draws itself; the Button base class supplies taps, hover and the disabled state.

const DESIGN_W: float = 160.0

var card_id: String = ""
var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()

var _card: Dictionary = {}
var _body := StyleBoxFlat.new()
var _ribbon := StyleBoxFlat.new()


func setup(id: String) -> CardView:
	card_id = id
	_card = GameData.cards[id]
	text = ""
	focus_mode = Control.FOCUS_NONE
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, empty)
	custom_minimum_size = Vector2(0, 188)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	return self


func _draw() -> void:
	if _card.is_empty():
		return
	var rc: Color = UiKit.RARITY_COLORS[_card["rarity"]]
	var hovered := is_hovered() and not disabled
	# The card is designed for a width of DESIGN_W. Narrower cards (a hand of 4 or more) draw the
	# whole design scaled down, so names, icons and text never spill onto the neighbors.
	var k := clampf(size.x / DESIGN_W, 0.55, 1.0)
	var dsz := size / k
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
	var frame_tex := UiKit.ui_texture("card_frame")
	var plate_tex := UiKit.ui_texture("card_plate")
	if frame_tex != null and plate_tex != null:
		_draw_textured(rc, hovered, dsz, frame_tex, plate_tex)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var r := Rect2(Vector2.ZERO, dsz).grow(-3.0)
	# Card body.
	_body.bg_color = Color("fbefd0") if (selected or hovered) else UiKit.PARCHMENT
	_body.set_corner_radius_all(16)
	_body.set_border_width_all(7 if selected else 5)
	_body.border_color = UiKit.GOLD if selected else rc
	_body.shadow_color = Color(1.0, 0.82, 0.3, 0.6) if selected else Color(0, 0, 0, 0.3)
	_body.shadow_size = 14 if selected else 5
	_body.shadow_offset = Vector2(0, 0) if selected else Vector2(0, 3)
	draw_style_box(_body, r)
	# Rarity ribbon with the card name, shrunk to fit if needed.
	var ribbon_rect := Rect2(r.position + Vector2(5, 5), Vector2(r.size.x - 10, 34))
	_ribbon.bg_color = rc
	_ribbon.corner_radius_top_left = 11
	_ribbon.corner_radius_top_right = 11
	draw_style_box(_ribbon, ribbon_rect)
	var font := UiKit.bold_font()
	var name_text: String = _card["name"]
	var fs := 18 if name_text.length() <= 11 else 16
	var tw := font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
	while tw > dsz.x - 24.0 and fs > 11:
		fs -= 1
		tw = font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
	var np := Vector2((dsz.x - tw) / 2.0, ribbon_rect.position.y + 24.0)
	draw_string_outline(font, np, name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0.1, 0.07, 0.05, 0.7))
	draw_string(font, np, name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	# Icon and description. When the scaled card is taller than designed, spread them out.
	var extra := maxf(0.0, dsz.y - 176.0)
	UiKit.draw_card_icon(self, Rect2(r.position + Vector2(8, 42 + extra * 0.28), Vector2(r.size.x - 16, 56)), _card)
	draw_multiline_string(ThemeDB.fallback_font, Vector2(r.position.x + 8, r.position.y + 116.0 + extra * 0.6), _card["desc"],
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 16.0, 14, 3 if k > 0.95 else 5, UiKit.INK)
	if disabled:
		_body.bg_color = Color(0.05, 0.03, 0.02, 0.5)
		_body.set_border_width_all(0)
		_body.shadow_size = 0
		draw_style_box(_body, r)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Card drawn with the generated frame and name plate (both pale, tinted by rarity).
## dsz is the card size in design units (the caller has already applied the scale).
func _draw_textured(rc: Color, hovered: bool, dsz: Vector2, frame_tex: Texture2D, plate_tex: Texture2D) -> void:
	# Parchment inside the frame; gold glow when selected.
	_body.bg_color = Color("fbefd0") if (selected or hovered) else UiKit.PARCHMENT
	_body.set_corner_radius_all(14)
	_body.set_border_width_all(0)
	_body.shadow_color = Color(1.0, 0.82, 0.3, 0.75) if selected else Color(0, 0, 0, 0.3)
	_body.shadow_size = 16 if selected else 5
	_body.shadow_offset = Vector2.ZERO if selected else Vector2(0, 3)
	var inner := Rect2(Vector2(5, 5), dsz - Vector2(10, 10))
	draw_style_box(_body, inner)
	var fs := StyleBoxTexture.new()
	fs.texture = frame_tex
	fs.texture_margin_left = 26.0
	fs.texture_margin_right = 26.0
	fs.texture_margin_top = 26.0
	fs.texture_margin_bottom = 26.0
	fs.draw_center = false
	fs.modulate_color = UiKit.GOLD.lightened(0.1) if selected else rc.lightened(0.3)
	draw_style_box(fs, Rect2(Vector2.ZERO, dsz))
	# Name plate, tinted by rarity, with the name shrunk to fit.
	var plate := Rect2(Vector2(14, 12), Vector2(dsz.x - 28, 36))
	draw_texture_rect(plate_tex, plate, false, rc.lightened(0.25))
	var font := UiKit.bold_font()
	var name_text: String = _card["name"]
	var fsz := 16 if name_text.length() <= 11 else 14
	var tw := font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_CENTER, -1, fsz).x
	var limit := plate.size.x * 0.68
	while tw > limit and fsz > 10:
		fsz -= 1
		tw = font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_CENTER, -1, fsz).x
	var np := Vector2(plate.position.x + (plate.size.x - tw) / 2.0, plate.position.y + plate.size.y * 0.5 + fsz * 0.34)
	draw_string_outline(font, np, name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, 5, Color(0.1, 0.07, 0.05, 0.75))
	draw_string(font, np, name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, Color.WHITE)
	# Icon and description, spread out when the scaled card is taller than designed.
	var extra := maxf(0.0, dsz.y - 188.0)
	UiKit.draw_card_icon(self, Rect2(Vector2(20, 54 + extra * 0.28), Vector2(dsz.x - 40, 52)), _card)
	draw_multiline_string(ThemeDB.fallback_font, Vector2(20, 126.0 + extra * 0.6), _card["desc"],
		HORIZONTAL_ALIGNMENT_CENTER, dsz.x - 40.0, 13, 3 if dsz.x < 175.0 and dsz.y < 205.0 else 5, UiKit.INK)
	if disabled:
		_body.bg_color = Color(0.05, 0.03, 0.02, 0.5)
		_body.shadow_size = 0
		draw_style_box(_body, inner)
