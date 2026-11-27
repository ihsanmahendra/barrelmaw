class_name DailyScreens
extends RefCounted
## The Daily Haul screens: today's picture before playing and the score after. The screen manager (main.gd)
## provides the shared helpers, so `m` is left untyped on purpose. Spec: design/gdd/daily-challenge.md.

const WEEKDAYS: Array = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
const MONTHS: Array = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
const BROWN := Color("6b4a2f")
const SOFT := Color("8a5a30")

var m  # the screen manager (main.gd)


func _init(main) -> void:
	m = main


## "27 November", or "Friday, 27 November" with the weekday.
static func date_words(date: String, with_weekday: bool = false) -> String:
	var d := Time.get_datetime_dict_from_unix_time(Time.get_unix_time_from_datetime_string(date))
	var text := "%d %s" % [d["day"], MONTHS[int(d["month"]) - 1]]
	return "%s, %s" % [WEEKDAYS[int(d["weekday"])], text] if with_weekday else text


func _panel(box: VBoxContainer) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.parchment_style())
	box.add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	panel.add_child(inner)
	return inner


func _line(inner: VBoxContainer, text: String, size: int, color: Color, bold: bool = false) -> Label:
	var l: Label = m._label(text, size, color, HORIZONTAL_ALIGNMENT_CENTER, bold, false)
	inner.add_child(l)
	return l


func _chip(caption: String, value: String, value_color: Color) -> Control:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.2, 0.12, 0.07, 0.94), Color("a8743f"), 3, 12))
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 0)
	chip.add_child(rows)
	rows.add_child(m._label(caption, 12, Color("d9b98c"), HORIZONTAL_ALIGNMENT_CENTER, true, false))
	rows.add_child(m._label(value, 21, value_color, HORIZONTAL_ALIGNMENT_CENTER, true, false))
	return chip


func show_start() -> void:
	var date := SaveData.today()
	var index := DailyHaul.stage_index(date)
	var pic := Stages.picture(index)
	var entry := SaveData.daily_entry(date)
	var box: VBoxContainer = m._new_screen(10)
	box.add_child(RibbonLabel.new("Daily Haul", 40))
	var inner := _panel(box)
	_line(inner, date_words(date, true), 17, SOFT)
	var preview := PicturePreview.new()
	preview.custom_minimum_size = Vector2(0, 220)
	preview.set_picture(pic["rows"])
	inner.add_child(preview)
	_line(inner, String(pic["name"]), 32, UiKit.INK, true)
	_line(inner, "Same barrels and cards for everyone", 16, SOFT)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	chips.add_child(_chip("PAR", "%d turns" % DailyHaul.par(date), UiKit.CREAM))
	var best := "-"
	if not entry.is_empty():
		best = "%d turns" % int(entry["best"]["turns"]) if bool(entry["best"]["won"]) else "sunk"
	chips.add_child(_chip("YOUR BEST", best, UiKit.CREAM))
	var paid := not entry.is_empty() and bool(entry["paid"])
	chips.add_child(_chip("REWARD", "claimed" if paid else str(DailyHaul.REWARD), UiKit.GOLD))
	inner.add_child(chips)
	box.add_child(m._spacer())
	box.add_child(m._button("Play today's haul" if entry.is_empty() else "Try for a better score", func() -> void: m._begin_daily(date)))
	if not entry.is_empty():
		box.add_child(m._button("Share first try", func() -> void: _share(date), Color("2a9d8f")))
	box.add_child(m._button("Back", m.show_menu, m.WOOD))


## Score of the attempt just finished. `paid` is the Doubloons it earned.
func show_result(date: String, result: Dictionary, paid: int) -> void:
	var entry := SaveData.daily_entry(date)
	var won := bool(result["won"])
	var turns := int(result["turns"])
	var par := DailyHaul.par(date)
	var box: VBoxContainer = m._new_screen(10)
	var ribbon := RibbonLabel.new("Daily Haul", 40)
	ribbon.custom_minimum_size = Vector2(0, 96)
	box.add_child(ribbon)
	var inner := _panel(box)
	_line(inner, "Plundered!" if won else "Out of cannonballs", 34, UiKit.INK, true)
	_line(inner, "%s - %s" % [date_words(date), Stages.picture(DailyHaul.stage_index(date))["name"]], 16, SOFT)
	_line(inner, str(turns), 68, UiKit.INK, true)
	_line(inner, "turn%s (par %d)" % ["" if turns == 1 else "s", par], 19, BROWN)
	inner.add_child(_squares(turns, par))
	_line(inner, "one square per turn, gold = over par", 15, SOFT)
	if paid > 0:
		_line(inner, "+%d Doubloons" % paid, 23, Color("a8651a"), true)
	if not entry.is_empty():
		var first: Dictionary = entry["first"]
		var shared := "%d turns" % int(first["turns"]) if bool(first["won"]) else "not cleared"
		_line(inner, "Shared score (first try): %s" % shared, 14, SOFT)
	_line(inner, "v%s" % str(ProjectSettings.get_setting("application/config/version", "0.1.0")), 12, SOFT)
	box.add_child(m._spacer())
	box.add_child(m._button("Share", func() -> void: _share(date), Color("2a9d8f")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for pair in [["Try again", func() -> void: m._begin_daily(date)], ["Menu", m.show_menu]]:
		var b: Button = m._button(pair[0], pair[1], m.WOOD)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	box.add_child(row)


## One square per turn, appearing one by one.
func _squares(turns: int, par: int) -> Control:
	var per_row := 12
	var c := Control.new()
	var rows := maxi(1, int(ceil(turns / float(per_row))))
	c.custom_minimum_size = Vector2(0, rows * 30.0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shown := [0]
	c.draw.connect(func() -> void:
		for i in int(shown[0]):
			var row := i / per_row
			var in_row := mini(per_row, turns - row * per_row)
			var start: float = (c.size.x - in_row * 30.0 + 6.0) / 2.0
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color("4cc9f0") if i < par else Color("ffd166")
			sb.set_corner_radius_all(6)
			c.draw_style_box(sb, Rect2(Vector2(start + (i % per_row) * 30.0, row * 30.0), Vector2(24, 24))))
	var timer := Timer.new()
	timer.wait_time = 0.06
	timer.autostart = true
	timer.timeout.connect(func() -> void:
		if shown[0] < turns:
			shown[0] += 1
			c.queue_redraw()
		else:
			timer.stop())
	c.add_child(timer)
	return c


func _share(date: String) -> void:
	var entry := SaveData.daily_entry(date)
	if entry.is_empty():
		return
	DisplayServer.clipboard_set(DailyHaul.share_text(date, entry["first"]))
	m._toast("Copied. Paste it anywhere to share.", 2.0)
