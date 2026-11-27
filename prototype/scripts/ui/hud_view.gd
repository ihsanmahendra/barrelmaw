class_name HudView
extends Control
## Top bar of the battle screen: a title plank, three counters (barrels left, hits left,
## projected stars) and a warning line when the cannonballs cannot clear the board yet.

var title: String = ""
var barrels: int = 0
var hits: int = 0
var stars: int = -1  # projected star rating (1-3); -1 hides the third counter (practice picture)
var warn: bool = false
var turn: int = 0
var limit: int = -1  # turn limit that keeps the current stars; -1 when none
var _sb := StyleBoxFlat.new()


func set_state(p_title: String, p_barrels: int, p_hits: int, p_stars: int, p_warn: bool, p_turn: int = 0, p_limit: int = -1) -> void:
	title = p_title
	barrels = p_barrels
	hits = p_hits
	stars = p_stars
	warn = p_warn
	turn = p_turn
	limit = p_limit
	queue_redraw()


func _chip(rect: Rect2, border: Color) -> void:
	_sb.bg_color = Color(0.2, 0.12, 0.07, 0.88)
	_sb.set_corner_radius_all(14)
	_sb.set_border_width_all(3)
	_sb.border_color = border
	_sb.shadow_color = Color(0, 0, 0, 0.3)
	_sb.shadow_size = 4
	_sb.shadow_offset = Vector2(0, 2)
	draw_style_box(_sb, rect)


func _number(rect: Rect2, text: String, col: Color) -> void:
	var font := UiKit.bold_font()
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var pos := Vector2(rect.end.x - tw - 12.0, rect.position.y + rect.size.y / 2.0 + 9.0)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 6, Color(0, 0, 0, 0.7))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, col)


func _draw() -> void:
	var font := UiKit.bold_font()
	var y := 0.0
	if title != "":
		var plank := Rect2(Vector2(size.x * 0.1, 0), Vector2(size.x * 0.8, 36))
		draw_style_box(UiKit.plank_style(UiKit.WOOD), plank.grow(0))
		var fs := 21
		var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		while tw > plank.size.x - 28.0 and fs > 13:  # long picture names with a rule name
			fs -= 1
			tw = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2(plank.position.x + (plank.size.x - tw) / 2.0, 25.0)
		draw_string_outline(font, pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0.1, 0.06, 0.03, 0.9))
		draw_string(font, pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiKit.CREAM)
		y = 46.0
	var count := 3 if stars >= 0 else 2
	var gap := 10.0
	var w := (size.x - gap * (count - 1)) / count
	var h := 40.0
	var barrel_chip := Rect2(Vector2(0, y), Vector2(w, h))
	var hits_chip := Rect2(Vector2(w + gap, y), Vector2(w, h))
	_chip(barrel_chip, Color("a8743f"))
	PirateArt.draw_barrel(self, barrel_chip.position + Vector2(24, h / 2.0), 26.0, 32.0, Color("a47148"))
	_number(barrel_chip, str(barrels), UiKit.CREAM)
	_chip(hits_chip, Color("8d93a5"))
	PirateArt.draw_cannonball(self, hits_chip.position + Vector2(24, h / 2.0), 13.0, Color("b9c0d4"))
	_number(hits_chip, str(hits), Color("ff9aa8") if warn else UiKit.CREAM)
	if stars >= 0:
		var stars_chip := Rect2(Vector2((w + gap) * 2.0, y), Vector2(w, h))
		_chip(stars_chip, Color("e0a020"))
		for i in 3:
			var c := stars_chip.position + Vector2(22.0 + i * 21.0, h / 2.0)
			if i < stars:
				UiKit.draw_star(self, c, 9.0, UiKit.GOLD, Color("a8651a"))
			else:
				UiKit.draw_star(self, c, 9.0, Color(0.15, 0.1, 0.07, 0.6), Color(0.5, 0.4, 0.3, 0.8))
		var turn_text := "%d/%d" % [turn, limit] if limit > 0 else "%d" % turn
		_number(stars_chip, turn_text, UiKit.CREAM if limit < 0 or turn < limit else Color("ffd9a0"))
