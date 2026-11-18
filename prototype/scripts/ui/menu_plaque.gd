class_name MenuPlaque
extends Control
## Small wooden plaque on the menu showing the next goal: which stage is next, how far the next boss
## is, and the star total with a gold star icon.

var stage_index: int = 0
var picture_name: String = ""
var stars_total: int = 0
var stars_max: int = 150
var all_done: bool = false
var gift_waiting: String = ""


func set_info(index: int, p_name: String, total: int, maximum: int, done: bool, gift: String) -> void:
	stage_index = index
	picture_name = p_name
	stars_total = total
	stars_max = maximum
	all_done = done
	gift_waiting = gift
	custom_minimum_size = Vector2(0, 96)
	queue_redraw()


func _draw() -> void:
	var panel := UiKit.panel_style(Color(0.2, 0.12, 0.07, 0.9), Color("a8743f"), 3, 16)
	draw_style_box(panel, Rect2(Vector2(size.x * 0.5 - 190.0, 0.0), Vector2(380.0, size.y)))
	var font := UiKit.bold_font()
	var left := size.x * 0.5 - 190.0 + 18.0
	var line1 := ("All %d stages cleared!" % Stages.TOTAL) if all_done else "Next: Stage %d  -  %s" % [stage_index + 1, picture_name]
	draw_string(font, Vector2(left, 32.0), line1, HORIZONTAL_ALIGNMENT_LEFT, 350.0, 21, UiKit.CREAM)
	var boss := Stages.next_boss(stage_index)
	var line2 := ""
	if not all_done:
		var away := boss - stage_index
		line2 = "Boss stage!" if away == 0 else ("Boss in %d stage%s" % [away, "" if away == 1 else "s"])
	if gift_waiting != "":
		line2 = (line2 + "   -   " if line2 != "" else "") + "Gift card ready"
	draw_string(ThemeDB.fallback_font, Vector2(left, 58.0), line2, HORIZONTAL_ALIGNMENT_LEFT, 350.0, 16, Color("ffd9a0"))
	UiKit.draw_star(self, Vector2(left + 12.0, 80.0), 9.0, UiKit.GOLD, Color("a8651a"))
	draw_string(font, Vector2(left + 28.0, 86.0), "%d / %d stars" % [stars_total, stars_max], HORIZONTAL_ALIGNMENT_LEFT, 300.0, 16, UiKit.CREAM)
