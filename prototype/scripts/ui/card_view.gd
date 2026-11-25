class_name CardView
extends Button
## A playing card: rarity ribbon with the name, an icon showing what it does, and short text.
## Draws itself; the Button base class supplies taps, hover and the disabled state.

const DESIGN_W: float = 160.0
const LEVEL_COLORS: Dictionary = {2: Color("d08a4a"), 3: Color("d7dfec"), 4: Color("ffd166"), 5: Color("a8f0ff")}

var card_id: String = ""
var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()

## Card level (1 to 5). Above level 1 the card shows a level badge and what the level adds.
var level: int = 1

var _card: Dictionary = {}
var _shimmer_wait: float = 0.0
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
	set_process(_card["rarity"] == "transcended")  # only the shimmering cards redraw every frame
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	return self


## The shimmer of a Transcended card: redrawn at 30 fps, and only while the card is on screen (a Cargo Hold
## full of cards scrolled out of view should cost nothing).
func _process(delta: float) -> void:
	_shimmer_wait += delta
	if _shimmer_wait < 1.0 / 30.0 or not is_visible_in_tree():
		return
	var vp := get_viewport_rect()
	var r := get_global_rect()
	if r.end.y < 0.0 or r.position.y > vp.size.y:
		return
	_shimmer_wait = 0.0
	queue_redraw()


func set_level(value: int) -> CardView:
	level = value
	queue_redraw()
	return self


## Level badge in the top right corner, and the bonus text under the description.
func _draw_level(dsz: Vector2, text_y: float, text_width: float) -> void:
	if level < 2:
		return
	var font := UiKit.bold_font()
	var c := Vector2(dsz.x - 22.0, 22.0)
	var badge_col: Color = LEVEL_COLORS[clampi(level, 2, 5)]  # bronze, silver, gold, then a prismatic ice-blue
	draw_circle(c, 13.0, Color(0.16, 0.1, 0.05, 0.95))
	draw_circle(c, 11.0, badge_col)
	if level >= 5:
		draw_arc(c, 15.5, 0.0, TAU, 20, Color(1, 1, 1, 0.8), 2.0)
	var label := str(level)
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 15).x
	draw_string(font, c + Vector2(-tw / 2.0, 5.5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.25, 0.14, 0.04))
	var bonus := CardLevels.bonus_text(_card, level)
	if bonus != "":
		draw_multiline_string(font, Vector2(20.0, text_y), "Lv %d: %s" % [level, bonus], HORIZONTAL_ALIGNMENT_CENTER, text_width, 12, 2, Color("2d6a34"))


## Y position just under the description, where the level bonus text goes.
func _bonus_y(desc_y: float, width: float, max_lines: int) -> float:
	var size_px := ThemeDB.fallback_font.get_multiline_string_size(_card["desc"], HORIZONTAL_ALIGNMENT_CENTER, width, 13, max_lines)
	return desc_y + size_px.y + 2.0


func _draw() -> void:
	if _card.is_empty():
		return
	var rc: Color = UiKit.RARITY_COLORS[_card["rarity"]]
	if _card["rarity"] == "transcended":
		rc = UiKit.aurora(float(Time.get_ticks_msec()) / 1000.0)  # shimmering frame
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
	_draw_level(dsz, r.position.y + 116.0 + extra * 0.6 + 44.0, r.size.x - 16.0)
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
	# A card with a level bonus line lifts its description a little so both fit above the frame.
	var desc_y := 126.0 + extra * 0.6 - (12.0 if level > 1 else 0.0)
	var max_lines := 3 if dsz.x < 175.0 and dsz.y < 205.0 else 5
	draw_multiline_string(ThemeDB.fallback_font, Vector2(20, desc_y), _card["desc"],
		HORIZONTAL_ALIGNMENT_CENTER, dsz.x - 40.0, 13, max_lines, UiKit.INK)
	_draw_level(dsz, _bonus_y(desc_y, dsz.x - 40.0, max_lines), dsz.x - 40.0)
	if disabled:
		_body.bg_color = Color(0.05, 0.03, 0.02, 0.5)
		_body.shadow_size = 0
		draw_style_box(_body, inner)
