class_name RibbonLabel
extends Control
## A heading on the generated red ribbon banner (falls back to plain text if the art is missing).

const BAND_CENTER := 0.33  # vertical centre of the red band, as a fraction of the ribbon picture's height

var text: String = ""
var font_size: int = 38


func _init(p_text: String = "", p_size: int = 38) -> void:
	text = p_text
	font_size = p_size
	custom_minimum_size = Vector2(0, 130)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var tex := UiKit.ui_texture("ribbon")
	var font := UiKit.bold_font()
	var area := Rect2(Vector2.ZERO, size)
	if tex != null:
		var aspect := float(tex.get_height()) / float(tex.get_width())
		var w := minf(size.x, size.y / aspect)
		var h := w * aspect
		area = Rect2(Vector2((size.x - w) / 2.0, (size.y - h) / 2.0), Vector2(w, h))
		draw_texture_rect(tex, area, false)
	var fs := font_size
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var limit := area.size.x * 0.62
	if tw > limit:
		fs = int(float(fs) * limit / tw)
		tw = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	# The ribbon's main band fills the top ~62% of the picture (the tails hang lower), so its centre is at
	# about a third of the height, not the middle of the picture.
	var pos := Vector2(area.position.x + (area.size.x - tw) / 2.0, area.position.y + area.size.y * BAND_CENTER + fs * 0.34)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(0.35, 0.05, 0.08, 0.95))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiKit.CREAM)
