class_name AlbumScreen
extends RefCounted
## The Captain's Log screen: page tabs, a grid of pictures and the page rewards. The screen manager
## (main.gd) provides the shared helpers, so `m` is left untyped on purpose.

const NIGHT_PLATE := Color("22305c")
const DAY_PLATE := Color("6b4a2f")

var m  # the screen manager (main.gd)
var page: int = 0


func _init(main) -> void:
	m = main


## The page to open: the first with a reward waiting, else the one with the next stage to play.
func default_page() -> int:
	var stars := SaveData.best_stars()
	for p in Album.pages():
		for kind in Album.KINDS:
			if Album.claimable(SaveData.pack_state(), p, kind, stars):
				return p
	return SaveData.highest_unlocked() / Album.PAGE_SIZE


func show(p: int = -1) -> void:
	page = default_page() if p < 0 else clampi(p, 0, Album.pages() - 1)
	var stars := SaveData.best_stars()
	var box: VBoxContainer = m._new_screen(6)
	var ribbon := RibbonLabel.new("Captain's Log", 38)
	ribbon.custom_minimum_size = Vector2(0, 84)
	box.add_child(ribbon)
	box.add_child(_tabs(stars))

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.parchment_style())
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	panel.add_child(inner)
	var first: int = Album.stages_on(page)[0]
	inner.add_child(m._label("Page %d - stages %d to %d" % [page + 1, first + 1, first + Album.stages_on(page).size()], 20, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true, false))
	var scroll := DragScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 150)
	inner.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	for i in Album.stages_on(page):
		grid.add_child(_tile(i, int(stars[i])))
	scroll.wire(grid)

	box.add_child(_rewards(stars))
	var back: Button = m._button("Back", m.show_menu, m.WOOD)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.custom_minimum_size = Vector2(240, 54)
	box.add_child(back)


func _tabs(stars: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	for p in Album.pages():
		var b := Button.new()
		b.text = str(p + 1)
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 46)
		b.add_theme_font_override("font", UiKit.bold_font())
		b.add_theme_font_size_override("font_size", 18)
		var fill := Color("ef476f") if p == page else (NIGHT_PLATE if p * Album.PAGE_SIZE >= Stages.NIGHT_START else DAY_PLATE)
		var sb := UiKit.panel_style(fill, Color.WHITE if p == page else Color("3a1f12"), 3, 10)
		for state in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(state, sb)
		for state in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(state, UiKit.CREAM)
		b.pressed.connect(func() -> void:
			m.sfx.play("click")
			show(p))
		for kind in Album.KINDS:
			if Album.claimable(SaveData.pack_state(), p, kind, stars):
				m._add_red_dot(b)
				break
		row.add_child(b)
	return row


## One picture: shown in color with its best stars once cleared, else a dark silhouette.
func _tile(index: int, best: int) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 112)  # ten pictures fit a 540 x 960 screen
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.set_meta("stage", index)
	b.set_meta("stars", best)
	b.draw.connect(_draw_tile.bind(b, index, best))
	b.pressed.connect(func() -> void:
		if best > 0:
			m.sfx.play("click", 1.1)
			m._open_popup(index)
		else:
			m.sfx.play("click", 0.6)
			m._toast("Clear stage %d to add its picture." % (index + 1)))
	return b


func _draw_tile(b: Button, index: int, best: int) -> void:
	var night := Stages.is_night(index)
	var cleared := best > 0
	var sb := StyleBoxFlat.new()
	if night:
		sb.bg_color = NIGHT_PLATE if cleared else Color(0.13, 0.18, 0.36, 0.45)
	else:
		sb.bg_color = Color("fbf0d4") if cleared else Color(0.55, 0.4, 0.25, 0.22)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(5 if best == 3 else 3)
	sb.border_color = Color("e0a020") if best == 3 else (Color("8a5a30") if cleared else Color(0.45, 0.32, 0.2, 0.5))
	b.draw_style_box(sb, Rect2(Vector2.ZERO, b.size))
	var rows: Array = Stages.picture(index)["rows"]
	var w := 0
	for r in rows:
		w = maxi(w, String(r).length())
	var area := Vector2(b.size.x - 20.0, 54.0)
	var cs := minf(area.x / w, area.y / rows.size())
	var origin := Vector2((b.size.x - w * cs) / 2.0, 8.0 + (area.y - rows.size() * cs) / 2.0)
	var shadow := Color(0.7, 0.75, 0.9, 0.28) if night else Color(0.27, 0.19, 0.13, 0.7)
	for y in rows.size():
		for x in String(rows[y]).length():
			var ch := String(rows[y])[x]
			if ch == ".":
				continue
			var col := GameData.color_of(ch) if cleared else shadow
			b.draw_rect(Rect2(origin + Vector2(x, y) * cs, Vector2(cs, cs)).grow(-0.5), col)
	var font := UiKit.bold_font()
	var ink := UiKit.CREAM if night else UiKit.INK
	var name: String = String(Stages.picture(index)["name"]) if cleared else "Stage %d" % (index + 1)
	var fs := 15
	while font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > b.size.x - 12.0 and fs > 10:
		fs -= 1
	var tw := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	b.draw_string(font, Vector2((b.size.x - tw) / 2.0, 79.0), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	if cleared:
		for k in 3:
			var at := Vector2(b.size.x / 2.0 + (k - 1) * 24.0, 96.0)
			if k < best:
				UiKit.draw_star(b, at, 10.0, UiKit.GOLD, Color("a8651a"))
			else:
				UiKit.draw_star(b, at, 10.0, Color(0.15, 0.1, 0.07, 0.55), Color(0.55, 0.45, 0.3, 0.8))
	else:
		var note := "not cleared"
		var nw := font.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		b.draw_string(font, Vector2((b.size.x - nw) / 2.0, 98.0), note, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(ink, 0.75))


## The page's two rewards: progress, or a button to claim.
func _rewards(stars: Array) -> PanelContainer:
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.2, 0.12, 0.07, 0.94), Color("a8743f"), 3, 14))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	plate.add_child(rows)
	var total: int = Album.stages_on(page).size()
	rows.add_child(_reward_row("complete", "Page cleared %d / %d" % [Album.cleared_count(page, stars), total],
		"%d Doubloons" % Album.COMPLETE_DOUBLOONS, Album.cleared_count(page, stars) / float(total), stars))
	rows.add_child(_reward_row("mastered", "Stars %d / %d" % [Album.star_count(page, stars), total * 3],
		str(PackConfig.chest(Album.MASTER_CHEST)["name"]), Album.star_count(page, stars) / float(total * 3), stars))
	return plate


func _reward_row(kind: String, progress_text: String, prize: String, fraction: float, stars: Array) -> Control:
	var st := SaveData.pack_state()
	if Album.claimable(st, page, kind, stars):
		var claim: Button = m._button("Claim: %s" % prize, func() -> void: _claim(kind), Color("2a9d8f"))
		claim.custom_minimum_size = Vector2(0, 44)
		claim.add_theme_font_size_override("font_size", 19)
		claim.name = "claim_%s" % kind
		return claim
	var row := Control.new()
	row.custom_minimum_size = Vector2(0, 34)
	var done := Album.claimed(st, page, kind)
	row.draw.connect(func() -> void:
		var font := UiKit.bold_font()
		row.draw_string(font, Vector2(4, 17), progress_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiKit.CREAM)
		var right := "claimed" if done else prize
		var tw := font.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		row.draw_string(font, Vector2(row.size.x - tw - 4.0, 17), right, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiKit.GOLD)
		var bar := Rect2(Vector2(4, 24), Vector2(row.size.x - 8.0, 8.0))
		row.draw_rect(bar, Color(0, 0, 0, 0.5))
		row.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(fraction, 0.0, 1.0), bar.size.y)), Color("ffd166")))
	return row


func _claim(kind: String) -> void:
	if not Album.claim(SaveData.pack_state(), page, kind, SaveData.best_stars()):
		return
	SaveData.save()
	m.sfx.play("reward")
	show(page)
	m._toast("+%d Doubloons" % Album.COMPLETE_DOUBLOONS if kind == "complete" else "%s added to the Treasury" % PackConfig.chest(Album.MASTER_CHEST)["name"], 2.0)
