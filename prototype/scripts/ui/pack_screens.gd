class_name PackScreens
extends RefCounted
## The card pack screens: Treasury (chests), chest opening, Cargo Hold (collection, merge, Captain's
## Slots) and the Port Market. Built in code like the other screens; the screen manager (main.gd) provides
## the shared helpers (_new_screen, _label, _button ...), so `m` is left untyped on purpose.
## Design: design/gdd/card-packs.md, section 3.8.

const RARITY_NAMES: Dictionary = {"common": "Common", "rare": "Rare", "epic": "Epic", "legendary": "Legendary", "transcended": "Transcended"}
const CARD_W: float = 150.0
const WOOD := Color("6b4a2f")
const SHORT_NAMES: Dictionary = {"common": "Common", "rare": "Rare", "epic": "Epic", "legendary": "Legend", "transcended": "Transc."}

var m  # the screen manager (main.gd)
var _gen: int = 0  # bumped by every screen so a running reveal stops when the player leaves
var _detail: Control = null
var _cargo_list: VBoxContainer = null
var _cargo_filter: String = "all"
var _cargo_back: Callable = Callable()
var _cargo_merge_btn: Button = null
var _cargo_scroll: DragScroll = null
var _treasury_back: Callable = Callable()
var _burst_next: bool = false  # play a burst on the card the next time the detail view opens (after a merge)


func _init(main) -> void:
	m = main


func _st() -> Dictionary:
	return SaveData.pack_state()


func _progress() -> int:
	return SaveData.highest_unlocked()


func _card_name(id: String) -> String:
	return str(GameData.cards[id]["name"])


## Heading row: a back button, the title and (optionally) nothing else.
func _header(box: VBoxContainer, title: String, back: Callable, back_text: String = "Back") -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	var b: Button = m._button(back_text, back, WOOD)
	b.custom_minimum_size = Vector2(110, 52)
	b.add_theme_font_size_override("font_size", 20)
	header.add_child(b)
	var t: Label = m._label(title, 32, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(t)
	var gap := Control.new()  # keeps the title centered
	gap.custom_minimum_size = Vector2(110, 0)
	header.add_child(gap)
	box.add_child(header)


## A small pill with a coin or pearl icon and a number.
func _currency_chip(kind: String, value: int) -> Control:
	var chip := Control.new()
	chip.custom_minimum_size = Vector2(150, 44)
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.draw.connect(func() -> void:
		chip.draw_style_box(UiKit.panel_style(Color(0.2, 0.12, 0.07, 0.9), Color("a8743f"), 3, 16), Rect2(Vector2.ZERO, chip.size))
		var c := Vector2(26, chip.size.y / 2.0)
		if kind == "pearls":
			chip.draw_circle(c, 11.0, Color("f4eef8"))
			chip.draw_circle(c + Vector2(-3, -3), 4.0, Color(1, 1, 1, 0.9))
			chip.draw_arc(c, 11.0, 0.0, TAU, 18, Color("b9a9c9"), 2.0)
		else:
			chip.draw_circle(c, 12.0, Color("c88a1e"))
			chip.draw_circle(c, 9.5, UiKit.GOLD)
			chip.draw_arc(c, 6.0, 0.0, TAU, 14, Color("c88a1e"), 2.0)
		var f := UiKit.bold_font()
		var txt := str(value)
		chip.draw_string_outline(f, Vector2(48, 31), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 6, Color(0, 0, 0, 0.7))
		chip.draw_string(f, Vector2(48, 31), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UiKit.CREAM))
	return chip


func _small_button(text: String, callback: Callable, color: Color, width: float = 120.0) -> Button:
	var b: Button = m._button(text, callback, color)
	b.custom_minimum_size = Vector2(width, 46)
	b.add_theme_font_size_override("font_size", 18)
	return b


func _enable(b: Button, on: bool) -> void:
	b.disabled = not on
	b.modulate = Color.WHITE if on else Color(1, 1, 1, 0.5)


# ---------- Treasury ----------

## Number of chests the player can open right now (owned and unlocked).
func openable_count() -> int:
	var st := _st()
	var n := 0
	for c in PackConfig.chests:
		if Packs.is_unlocked(str(c["id"]), _progress()):
			n += Packs.count(st, str(c["id"]))
	return n


func odds_text(chest: Dictionary) -> String:
	var lines: Array = []
	var idx := 1
	for s in chest["slots"]:
		var cnt := int(s["count"])
		var label := "Card %d" % idx if cnt == 1 else "Cards %d-%d" % [idx, idx + cnt - 1]
		idx += cnt
		var parts: Array = []
		for r in PackConfig.data["rarities"]:
			var p := int(s["odds"].get(r, 0))
			if p > 0:
				parts.append("%s %d%%" % [RARITY_NAMES[r], p])
		lines.append("%s: %s" % [label, ", ".join(parts)])
	return "\n".join(lines)


func pity_lines() -> Array:
	var st := _st()
	var pity: Dictionary = st["pity"]
	var out: Array = []
	var e := int(PackConfig.pity("epic")) - int(pity["since_epic"])
	out.append("Epic or better is guaranteed within %d more cards from Ironbound chests and up." % maxi(e, 1))
	if _progress() >= 30:
		var l := int(PackConfig.pity("legendary")) - int(pity["since_legendary"])
		out.append("Legendary or better is guaranteed within %d more cards from Coffers and up." % maxi(l, 1))
	if _progress() >= PackConfig.transcended_unlock_cleared():
		var v := int(PackConfig.pity("vault_dry")) - int(pity["vault_dry"])
		out.append("A Transcended card is guaranteed within %d more Abyssal Vaults." % maxi(v, 1))
	return out


func show_treasury(back: Callable = Callable()) -> void:
	_gen += 1
	var st := _st()
	var progress := _progress()
	_treasury_back = back
	var goback: Callable = back if back.is_valid() else m.show_menu
	var box: VBoxContainer = m._new_screen(8)
	_header(box, "Treasury", goback, "Menu" if not back.is_valid() else "Back")
	var money := HBoxContainer.new()
	money.add_theme_constant_override("separation", 8)
	money.add_child(_currency_chip("doubloons", int(st["doubloons"])))
	money.add_child(_currency_chip("pearls", int(st["pearls"])))
	box.add_child(money)
	var scroll := DragScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for chest in PackConfig.chests:
		_chest_row(list, chest, goback)
	# Pity meters.
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.2, 0.12, 0.07, 0.9), Color("a8743f"), 3, 16))
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 4)
	panel.add_child(pv)
	pv.add_child(m._label("Luck meters", 18, UiKit.GOLD, HORIZONTAL_ALIGNMENT_LEFT, true))
	for line in pity_lines():
		pv.add_child(m._label(str(line), 14, UiKit.CREAM, HORIZONTAL_ALIGNMENT_LEFT, false, false))
	list.add_child(panel)
	scroll.wire(list)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	var to_market := func() -> void: show_market(func() -> void: show_treasury(back))
	var market: Button = m._button("Port Market", to_market, Color("2a9d8f"))
	market.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(market)
	var to_cargo := func() -> void: show_cargo(func() -> void: show_treasury(back))
	var cargo: Button = m._button("Cargo Hold", to_cargo, Color("6a4c93"))
	cargo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(cargo)
	box.add_child(bottom)
	# A reveal that was never finished (the app was closed while opening) plays again first.
	if not (st["pending"] as Array).is_empty():
		show_opening(back)


func _chest_row(list: VBoxContainer, chest: Dictionary, back: Callable) -> void:
	var st := _st()
	var id := str(chest["id"])
	var unlocked := Packs.is_unlocked(id, _progress())
	var owned := Packs.count(st, id)
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 4)
	list.add_child(holder)
	var panel := PanelContainer.new()
	var rc: Color = ChestArt.glow_color(id)
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.2, 0.12, 0.07, 0.92), rc.darkened(0.2) if unlocked else Color("5a4a3a"), 3, 16))
	holder.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var icon := ChestView.new(id, false)
	icon.custom_minimum_size = Vector2(92, 80)
	if not unlocked:
		icon.modulate = Color(0.45, 0.45, 0.5)
	row.add_child(icon)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	info.add_child(m._label(str(chest["name"]), 21, UiKit.CREAM, HORIZONTAL_ALIGNMENT_LEFT, true))
	var sub := "%d cards, %s or better" % [int(chest["cards"]), RARITY_NAMES[chest["rarity"]]]
	info.add_child(m._label(sub, 13, Color("e6d6b0"), HORIZONTAL_ALIGNMENT_LEFT, false, false))
	if unlocked:
		info.add_child(m._label("You have: %d" % owned, 16, UiKit.GOLD if owned > 0 else Color("b9a98a"), HORIZONTAL_ALIGNMENT_LEFT, true, false))
	else:
		info.add_child(m._label("Clear stage %d to unlock" % int(chest["unlock_cleared"]), 15, Color("ff9aa8"), HORIZONTAL_ALIGNMENT_LEFT, true, false))
	row.add_child(info)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	row.add_child(buttons)
	if unlocked:
		var open_btn := _small_button("Open", func() -> void: open_and_show(id, back), Color("2a9d8f"), 118)
		_enable(open_btn, owned > 0)
		buttons.add_child(open_btn)
		var price := int(chest["price"])
		var buy := _small_button("Buy %d" % price, func() -> void: _buy(id, back), Color("e0a020"), 118)
		_enable(buy, int(st["doubloons"]) >= price)
		buttons.add_child(buy)
	var odds: Label = m._label(odds_text(chest), 13, UiKit.CREAM, HORIZONTAL_ALIGNMENT_LEFT, false, false)
	odds.visible = false
	var odds_panel := PanelContainer.new()
	odds_panel.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.12, 0.08, 0.05, 0.95), Color("6b4a2f"), 2, 12))
	odds_panel.add_child(odds)
	odds_panel.visible = false
	holder.add_child(odds_panel)
	var toggle_odds := func() -> void:
		odds_panel.visible = not odds_panel.visible
		odds.visible = odds_panel.visible
	var odds_link := Button.new()
	odds_link.text = "Odds"
	odds_link.flat = true
	odds_link.focus_mode = Control.FOCUS_NONE
	odds_link.alignment = HORIZONTAL_ALIGNMENT_LEFT
	odds_link.custom_minimum_size = Vector2(0, 26)
	odds_link.add_theme_font_size_override("font_size", 15)
	odds_link.add_theme_font_override("font", UiKit.bold_font())
	for s in ["font_color", "font_hover_color", "font_pressed_color"]:
		odds_link.add_theme_color_override(s, Color("8fd3ff"))
	odds_link.pressed.connect(toggle_odds)
	info.add_child(odds_link)


func _buy(id: String, back: Callable) -> void:
	if Packs.buy(_st(), id, _progress()):
		SaveData.save()
		m.sfx.play("reward")
		show_treasury(_treasury_back)
	else:
		m.sfx.play("miss")


# ---------- chest opening ----------

## Opens a chest from the inventory and plays the reveal.
func open_and_show(chest_id: String, back: Callable = Callable()) -> void:
	var res := Packs.open_saved(chest_id)
	if not bool(res["ok"]):
		m._toast("Cannot open that chest (%s)." % str(res["reason"]), 1.6)
		return
	show_opening(back)


## A burst of light centered on a control (a card, a button).
func spawn_burst(target: Control, color: Color, power: float = 1.0, aurora: bool = false) -> void:
	var fx := BurstFx.new(color, power, aurora)
	m._overlay_layer.add_child(fx)
	var r := target.get_global_rect()
	fx.global_position = r.get_center() - fx.size / 2.0


func _flip(holder: Control, card_view: Control, back_face: Control, rarity: String) -> void:
	var tw: Tween = m.create_tween()
	holder.pivot_offset = holder.size / 2.0
	tw.tween_property(holder, "scale:x", 0.0, 0.1)
	tw.tween_callback(func() -> void:
		back_face.visible = false
		card_view.visible = true)
	tw.tween_property(holder, "scale:x", 1.0, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var tier: int = PackConfig.rank(rarity)
	m.sfx.play("flip")
	m.sfx.play("sting_" + rarity, 1.0, 0.12)
	if tier >= 3:
		m._flash(UiKit.RARITY_COLORS[rarity])
	if tier >= 1:
		var power: float = [0.5, 0.7, 1.0, 1.5, 2.2][tier]
		spawn_burst(holder, UiKit.RARITY_COLORS[rarity], power, tier >= 4)


## Full-screen reveal for a Transcended card the player owns for the first time. A tap continues.
func _transcended_splash(id: String) -> void:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m._overlay_layer.add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.08, 0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(holder)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(440, 0)
	holder.add_child(col)
	var title: Label = m._label("TRANSCENDED!", 44, UiKit.RARITY_COLORS["transcended"], HORIZONTAL_ALIGNMENT_CENTER, true)
	col.add_child(title)
	var card: Button = m._card_button(id, func() -> void: pass, 1)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size = Vector2(250, 300)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.pivot_offset = Vector2(125, 150)
	col.add_child(card)
	col.add_child(m._label(_card_name(id), 28, UiKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER, true))
	var slots := Collection.captain_slots(_progress())
	var note := "Equip it in the Cargo Hold to add it to your deck." if slots > 0 else "Clear stage %d to open a Captain's Slot for it." % PackConfig.transcended_unlock_cleared()
	col.add_child(m._label(note, 17, Color("c9f5ee"), HORIZONTAL_ALIGNMENT_CENTER, false))
	var hint: Label = m._label("Tap to continue", 16, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_CENTER, false)
	col.add_child(hint)
	var tap := Button.new()
	tap.flat = true
	tap.focus_mode = Control.FOCUS_NONE
	tap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(tap)
	card.scale = Vector2(0.6, 0.6)
	card.modulate.a = 0.0
	var tw: Tween = m.create_tween().set_parallel(true)
	tw.tween_property(card, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.25)
	m.sfx.play("sting_transcended")
	await m.get_tree().process_frame
	spawn_burst(card, UiKit.RARITY_COLORS["transcended"], 2.6, true)
	var auto := OS.get_cmdline_user_args().has("--auto-tap")
	if auto:
		await m.get_tree().create_timer(1.2).timeout
	else:
		await tap.pressed
	layer.queue_free()


func _card_info_text(entry: Dictionary) -> Array:
	var id := str(entry["id"])
	var st := _st()
	if bool(entry["new"]):
		return ["NEW!", UiKit.GOLD]
	if int(entry["pearls"]) > 0:
		return ["+%d Pearls (max level)" % int(entry["pearls"]), Color("f4eef8")]
	if Collection.is_ready(st, id, GameData.cards):
		return ["Ready to merge!", Color("7ee08a")]
	return ["Copies %d/%d" % [Collection.spare_of(st, id), maxi(Collection.need(st, id, GameData.cards), 1)], UiKit.CREAM]


## The full-screen reveal of the oldest unseen chest result. It is already saved, so leaving does not lose it.
func show_opening(back: Callable = Callable()) -> void:
	_gen += 1
	var gen := _gen
	var st := _st()
	if (st["pending"] as Array).is_empty():
		show_treasury(back)
		return
	var entry: Dictionary = st["pending"][0]
	var chest_id := str(entry["chest"])
	var cards: Array = entry["cards"]
	var chest := PackConfig.chest(chest_id)
	var box: VBoxContainer = m._new_screen(10)
	box.add_child(m._label(str(chest["name"]), 34, ChestArt.glow_color(chest_id), HORIZONTAL_ALIGNMENT_CENTER, true))
	var stage := Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.custom_minimum_size = Vector2(0, 420)
	box.add_child(stage)
	var intro := VBoxContainer.new()
	intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro.alignment = BoxContainer.ALIGNMENT_CENTER
	intro.add_theme_constant_override("separation", 10)
	intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(intro)
	var chest_view := ChestView.new(chest_id, true)
	chest_view.custom_minimum_size = Vector2(320, 280)
	chest_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chest_view.pivot_offset = Vector2(160, 140)
	intro.add_child(chest_view)
	var prompt: Label = m._label("Tap the chest to open it", 24, UiKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER, true)
	intro.add_child(prompt)
	var tap := Button.new()
	tap.flat = true
	tap.focus_mode = Control.FOCUS_NONE
	tap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(tap)
	var tween_pulse: Tween = prompt.create_tween().set_loops()  # bound to the label, so it ends with the screen
	tween_pulse.tween_property(prompt, "modulate:a", 0.45, 0.7)
	tween_pulse.tween_property(prompt, "modulate:a", 1.0, 0.7)
	m.sfx.play("deal")
	if OS.get_cmdline_user_args().has("--auto-tap"):  # debug: open without a tap
		await m.get_tree().create_timer(0.9).timeout
	else:
		await tap.pressed
	if gen != _gen:
		return
	tween_pulse.kill()
	prompt.visible = false
	tap.queue_free()
	# Shake, then the lid opens and the light pours out.
	m.sfx.play("chest_shake")
	var shake_tw: Tween = m.create_tween()
	shake_tw.tween_property(chest_view, "shake", 9.0, 0.55)
	shake_tw.tween_property(chest_view, "shake", 0.0, 0.05)
	shake_tw.tween_property(chest_view, "open_t", 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await shake_tw.finished
	if gen != _gen:
		return
	m.sfx.play("chest_open")
	m._flash(ChestArt.glow_color(chest_id))
	var fade: Tween = m.create_tween().set_parallel(true)
	fade.tween_property(chest_view, "modulate:a", 0.0, 0.5).set_delay(0.25)
	fade.tween_property(chest_view, "scale", Vector2(1.25, 1.25), 0.5).set_delay(0.25)
	# Face-down cards, three to a row.
	var holders: Array = []
	var views: Array = []
	var backs: Array = []
	var infos: Array = []
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	rows.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	stage.add_child(rows)
	var row: HBoxContainer = null
	for i in cards.size():
		if i % 3 == 0:
			row = HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 8)
			rows.add_child(row)
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		row.add_child(cell)
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(CARD_W, 192)
		cell.add_child(holder)
		var entry_card: Dictionary = cards[i]
		var cv: CardView = CardView.new().setup(str(entry_card["id"])).set_level(Collection.level_of(st, str(entry_card["id"])))
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cv.visible = false
		holder.add_child(cv)
		var back_face := Panel.new()
		var rc: Color = UiKit.RARITY_COLORS[str(entry_card["rarity"])]
		back_face.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.2, 0.12, 0.07), rc, 5, 14))
		back_face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		back_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(back_face)
		var q: Label = m._label("?", 64, rc, HORIZONTAL_ALIGNMENT_CENTER, true)
		q.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		back_face.add_child(q)
		var info: Label = m._label(" ", 14, UiKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER, true)
		info.custom_minimum_size = Vector2(CARD_W, 22)
		info.modulate.a = 0.0
		cell.add_child(info)
		holders.append(holder)
		views.append(cv)
		backs.append(back_face)
		infos.append(info)
	# Reveal one at a time, lowest rarity first (the list is already in that order). A tap skips ahead.
	var skip := Button.new()
	skip.flat = true
	skip.focus_mode = Control.FOCUS_NONE
	skip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(skip)
	var skipped := [false]
	skip.pressed.connect(func() -> void: skipped[0] = true)
	await m.get_tree().create_timer(0.55).timeout
	for i in cards.size():
		if gen != _gen:
			return
		_flip(holders[i], views[i], backs[i], str(cards[i]["rarity"]))
		var txt: Array = _card_info_text(cards[i])
		infos[i].text = str(txt[0])
		infos[i].add_theme_color_override("font_color", txt[1])
		infos[i].modulate.a = 1.0
		if bool(cards[i]["new"]):  # the first copy of a Transcended card is a moment of its own
			await m.get_tree().create_timer(0.5).timeout
			await _transcended_splash(str(cards[i]["id"]))
			if gen != _gen:
				return
		elif not skipped[0]:
			await m.get_tree().create_timer(0.55).timeout
	if gen != _gen:
		return
	skip.queue_free()
	# The reveal has been seen: take it off the queue.
	Packs.take_pending(st)
	SaveData.save()
	_opening_summary(box, chest_id, cards, back)


func _opening_summary(box: VBoxContainer, chest_id: String, cards: Array, back: Callable) -> void:
	var st := _st()
	var pearls := 0
	for c in cards:
		pearls += int(c["pearls"])
	var ready := Collection.ready_count(st, GameData.cards)
	var bits: Array = []
	if ready > 0:
		bits.append("%d card%s ready to merge" % [ready, "" if ready == 1 else "s"])
	if pearls > 0:
		bits.append("+%d Pearls" % pearls)
	var line: Label = m._label(", ".join(bits) if not bits.is_empty() else "Added to your collection.", 18, UiKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER, true)
	box.add_child(line)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	if ready > 0:
		var do_merge := func() -> void:
			Collection.merge_all(st, GameData.cards)
			SaveData.save()
			m.sfx.play("merge")
			m._toast("Merged! Your cards are stronger.", 1.4)
			show_cargo(func() -> void: show_treasury(back))
		var merge_btn: Button = m._button("Merge all (%d)" % ready, do_merge, Color("2a9d8f"))
		merge_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(merge_btn)
	var left := Packs.count(st, chest_id)
	if left > 0 and Packs.is_unlocked(chest_id, _progress()):
		var again: Button = m._button("Open another (%d)" % left, func() -> void: open_and_show(chest_id, back), Color("e0a020"))
		again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(again)
	var done: Button = m._button("Treasury", func() -> void: show_treasury(back), WOOD)
	box.add_child(done)


# ---------- Cargo Hold ----------

func show_cargo(back: Callable = Callable(), filter: String = "all") -> void:
	_gen += 1
	_cargo_filter = filter
	_cargo_back = back
	var goback: Callable = back if back.is_valid() else m.show_menu
	var box: VBoxContainer = m._new_screen(8)
	_header(box, "Cargo Hold", goback, "Menu" if not back.is_valid() else "Back")
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	box.add_child(bar)
	for f in ["all", "ready", "common", "rare", "epic", "legendary", "transcended"]:
		var label := "All" if f == "all" else ("Ready" if f == "ready" else str(SHORT_NAMES[f]))
		var chip := Button.new()
		chip.text = label
		chip.toggle_mode = false
		chip.focus_mode = Control.FOCUS_NONE
		chip.custom_minimum_size = Vector2(0, 38)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.add_theme_font_size_override("font_size", 14)
		chip.add_theme_font_override("font", UiKit.bold_font())
		var selected: bool = f == filter
		var col := UiKit.GOLD if selected else Color(0.2, 0.12, 0.07, 0.9)
		var sb := UiKit.panel_style(col, Color("a8743f"), 2, 12)
		for s in ["normal", "hover", "pressed"]:
			chip.add_theme_stylebox_override(s, sb)
		chip.add_theme_color_override("font_color", UiKit.INK if selected else UiKit.CREAM)
		chip.add_theme_color_override("font_hover_color", UiKit.INK if selected else UiKit.CREAM)
		chip.add_theme_color_override("font_pressed_color", UiKit.INK if selected else UiKit.CREAM)
		chip.pressed.connect(func() -> void:
			m.sfx.play("click")
			show_cargo(back, f))
		bar.add_child(chip)
	var merge_all_cb := func() -> void:
		var st2 := _st()
		var n := Collection.merge_all(st2, GameData.cards)
		SaveData.save()
		if n > 0:
			m.sfx.play("merge")
			m._flash(UiKit.GOLD)
		_fill_cargo()
	_cargo_merge_btn = m._button("", merge_all_cb, Color("2a9d8f"))
	_cargo_merge_btn.custom_minimum_size = Vector2(0, 50)
	_cargo_merge_btn.add_theme_font_size_override("font_size", 20)
	box.add_child(_cargo_merge_btn)
	var scroll := DragScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_cargo_scroll = scroll
	_cargo_list = VBoxContainer.new()
	_cargo_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cargo_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_cargo_list)
	_fill_cargo()


## (Re)builds the card grid for the current filter and updates the Merge all button.
func _fill_cargo() -> void:
	if _cargo_list == null or not is_instance_valid(_cargo_list):
		return
	for c in _cargo_list.get_children():
		c.queue_free()
	var st := _st()
	var progress := _progress()
	var owned := {}
	for id in Collection.unlocked_ids(progress, GameData.cards, st):
		owned[id] = true
	var ready := Collection.ready_count(st, GameData.cards)
	_cargo_merge_btn.text = "Merge all (%d)" % ready if ready > 0 else "Nothing to merge yet"
	_enable(_cargo_merge_btn, ready > 0)
	var ids: Array = []
	for id in GameData.card_order:
		var rarity := str(GameData.cards[id]["rarity"])
		if _cargo_filter == "ready" and not Collection.is_ready(st, id, GameData.cards):
			continue
		if _cargo_filter != "all" and _cargo_filter != "ready" and rarity != _cargo_filter:
			continue
		ids.append(id)
	# Cards you can use come first, highest rarity first.
	ids.sort_custom(func(a: String, b: String) -> bool:
		var oa := 0 if owned.has(a) else 1
		var ob := 0 if owned.has(b) else 1
		if oa != ob:
			return oa < ob
		return PackConfig.rank(str(GameData.cards[a]["rarity"])) > PackConfig.rank(str(GameData.cards[b]["rarity"])))
	if ids.is_empty():
		_cargo_list.add_child(m._label("No cards here yet.", 18, UiKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER, true))
		return
	var row: HBoxContainer = null
	for i in ids.size():
		if i % 3 == 0:
			row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			_cargo_list.add_child(row)
		var id := str(ids[i])
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 2)
		row.add_child(cell)
		var has := owned.has(id)
		var cv: Button = m._card_button(id, func() -> void: _show_detail(id), Collection.level_of(st, id) if has else 1)
		cv.custom_minimum_size = Vector2(0, 188)
		if not has:
			cv.modulate = Color(0.42, 0.42, 0.5)
		cell.add_child(cv)
		cell.add_child(_progress_bar(id, has))
	# Fill the last row so the cards keep their size.
	while row != null and row.get_child_count() < 3:
		var pad := Control.new()
		pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(pad)
	if _cargo_scroll != null and is_instance_valid(_cargo_scroll):
		_cargo_scroll.wire(_cargo_list)  # cards and bars take touches, so the list must listen to them


## Copy progress under a card: spare/needed, MERGE when ready, MAX at level 5, or how to unlock it.
func _progress_bar(id: String, has: bool) -> Control:
	var st := _st()
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 24)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func() -> void:
		var r := Rect2(Vector2(6, 3), bar.size - Vector2(12, 6))
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(9)
		sb.bg_color = Color(0.13, 0.08, 0.05, 0.9)
		bar.draw_style_box(sb, r)
		var label := ""
		var fill := 0.0
		var col := UiKit.GOLD
		var text_col := UiKit.CREAM
		if not has:
			var s := Collection.unlock_stage(id)
			label = "Stage %d" % s if s > 0 else "Chest only"
			text_col = Color("b9a98a")
		elif Collection.level_of(st, id) >= PackConfig.max_level():
			label = "MAX"
			fill = 1.0
		else:
			var need := Collection.need(st, id, GameData.cards)
			var spare := Collection.spare_of(st, id)
			fill = clampf(float(spare) / float(maxi(need, 1)), 0.0, 1.0)
			label = "%d/%d" % [spare, need]
			if spare >= need:
				col = Color("4cc96a")
				label = "MERGE"
		if fill > 0.0:
			sb.bg_color = col
			bar.draw_style_box(sb, Rect2(r.position, Vector2(maxf(r.size.y, r.size.x * fill), r.size.y)))
		var f := UiKit.bold_font()
		var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var pos := Vector2(r.position.x + (r.size.x - tw) / 2.0, r.position.y + r.size.y - 4.0)
		bar.draw_string_outline(f, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.7))
		bar.draw_string(f, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, text_col))
	return bar


func _close_detail() -> void:
	if _detail != null and is_instance_valid(_detail):
		_detail.queue_free()
	_detail = null


## A card up close: its level table, merge button and (for Transcended cards) the Captain's Slot.
func _show_detail(id: String) -> void:
	_close_detail()
	var st := _st()
	var progress := _progress()
	var card: Dictionary = GameData.cards[id]
	var has := Collection.unlocked_ids(progress, GameData.cards, st).has(id)
	var level := Collection.level_of(st, id) if has else 1
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m._overlay_layer.add_child(layer)
	_detail = layer
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.66)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(holder)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.parchment_style())
	panel.custom_minimum_size = Vector2(400, 0)
	holder.add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	panel.add_child(inner)
	var rarity := str(card["rarity"])
	inner.add_child(m._label(RARITY_NAMES[rarity], 15, UiKit.RARITY_COLORS[rarity].darkened(0.25), HORIZONTAL_ALIGNMENT_CENTER, true, false))
	var cv: Button = m._card_button(id, func() -> void: pass, level)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.custom_minimum_size = Vector2(160, 190)
	cv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(cv)
	if not has:
		var s := Collection.unlock_stage(id)
		var why := "Clear stage %d to unlock this card." % (s - 1) if s > 1 else "Only chests give this card. Clear stage %d, then find it in an Abyssal Vault." % PackConfig.transcended_unlock_cleared()
		inner.add_child(m._label(why, 16, Color("8a3a2a"), HORIZONTAL_ALIGNMENT_CENTER, true, false))
	else:
		var need := Collection.need(st, id, GameData.cards)
		var info := "Max level" if need == 0 else "Spare copies: %d / %d for level %d" % [Collection.spare_of(st, id), need, level + 1]
		inner.add_child(m._label(info, 17, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true, false))
	# What each level adds.
	for lv in range(1, PackConfig.max_level() + 1):
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		var reached := has and lv <= level
		var current := has and lv == level
		var name_col := Color("2d6a34") if reached else Color("8a6a4a")
		var tag: Label = m._label(("Lv %d" % lv) + ("  (now)" if current else ""), 16, name_col, HORIZONTAL_ALIGNMENT_LEFT, true, false)
		tag.custom_minimum_size = Vector2(110, 0)
		line.add_child(tag)
		var txt := "Base card" if lv == 1 else CardLevels.step_text(card, lv)
		var body: Label = m._label(txt, 16, UiKit.INK if reached else Color("8a6a4a"), HORIZONTAL_ALIGNMENT_LEFT, current, false)
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(body)
		inner.add_child(line)
	if has and Collection.is_ready(st, id, GameData.cards):
		var do_merge := func() -> void:
			Collection.merge(st, id, GameData.cards)
			SaveData.save()
			m.sfx.play("merge")
			m._flash(UiKit.GOLD)
			_fill_cargo()
			_burst_next = true
			_show_detail(id)
		inner.add_child(m._button("MERGE to level %d" % (level + 1), do_merge, Color("2a9d8f")))
	if has and rarity == "transcended":
		var slots := Collection.captain_slots(progress)
		var equipped := Collection.equipped_cards(st, progress, GameData.cards)
		inner.add_child(m._label("Captain's Slots: %d / %d" % [equipped.size(), slots], 16, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true, false))
		if equipped.has(id):
			var do_unequip := func() -> void:
				Collection.unequip(st, id)
				SaveData.save()
				_show_detail(id)
			inner.add_child(m._button("Unequip", do_unequip, WOOD))
		else:
			var do_equip := func() -> void:
				if Collection.equip(st, id, progress, GameData.cards):
					SaveData.save()
					m.sfx.play("reward")
				_show_detail(id)
			var eq: Button = m._button("Equip in a Captain's Slot", do_equip, Color("6a4c93"))
			_enable(eq, equipped.size() < slots)
			inner.add_child(eq)
	inner.add_child(m._button("Close", _close_detail, WOOD))
	panel.pivot_offset = Vector2(200, 300)
	panel.scale = Vector2(0.9, 0.9)
	panel.modulate.a = 0.0
	var tw: Tween = m.create_tween().set_parallel(true)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.12)
	if _burst_next:
		_burst_next = false
		await m.get_tree().process_frame
		if is_instance_valid(cv):
			spawn_burst(cv, UiKit.RARITY_COLORS[rarity], 1.4, rarity == "transcended")


# ---------- Port Market ----------

func show_market(back: Callable = Callable()) -> void:
	_gen += 1
	var st := _st()
	var progress := _progress()
	var today := SaveData.today()
	var goback: Callable = back if back.is_valid() else m.show_menu
	var box: VBoxContainer = m._new_screen(8)
	_header(box, "Port Market", goback, "Menu" if not back.is_valid() else "Back")
	var money := HBoxContainer.new()
	money.add_child(_currency_chip("pearls", int(st["pearls"])))
	box.add_child(money)
	var normal_left := Rewards.market_left(st, GameData.cards, today, false)
	var top_left := Rewards.market_left(st, GameData.cards, today, true)
	var info_panel := PanelContainer.new()  # on a dark plate, so the small text reads against the beach
	info_panel.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.2, 0.12, 0.07, 0.9), Color("a8743f"), 3, 14))
	var info_box := VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 4)
	info_panel.add_child(info_box)
	info_box.add_child(m._label("Pearls come from copies of cards that are already at the top level. Each week you can buy %d card copies, and %d Transcended copy." % [int(PackConfig.data["market"]["weekly_limit"]), int(PackConfig.data["market"]["weekly_limit_transcended"])], 14, UiKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER, false, false))
	info_box.add_child(m._label("Left this week: %d card copies, %d Transcended" % [normal_left, top_left], 16, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER, true, false))
	box.add_child(info_panel)
	var scroll := DragScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	var ids: Array = []
	for id in Collection.unlocked_ids(progress, GameData.cards, st):
		if Collection.level_of(st, id) < PackConfig.max_level():
			ids.append(id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		return PackConfig.rank(str(GameData.cards[a]["rarity"])) > PackConfig.rank(str(GameData.cards[b]["rarity"])))
	if ids.is_empty():
		list.add_child(m._label("Every card you own is at its top level.", 18, UiKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER, true))
	for id in ids:
		var rarity := str(GameData.cards[id]["rarity"])
		var is_top := rarity == "transcended"
		var price := Rewards.market_price(rarity)
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.2, 0.12, 0.07, 0.92), UiKit.RARITY_COLORS[rarity].darkened(0.2), 3, 14))
		list.add_child(panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		panel.add_child(row)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 0)
		info.add_child(m._label(_card_name(id), 20, UiKit.RARITY_COLORS[rarity].lightened(0.35), HORIZONTAL_ALIGNMENT_LEFT, true))
		var need := Collection.need(st, id, GameData.cards)
		info.add_child(m._label("%s, level %d, copies %d/%d" % [RARITY_NAMES[rarity], Collection.level_of(st, id), Collection.spare_of(st, id), need], 13, Color("e6d6b0"), HORIZONTAL_ALIGNMENT_LEFT, false, false))
		row.add_child(info)
		var do_buy := func() -> void:
			if Rewards.market_buy(st, id, progress, GameData.cards, today):
				SaveData.save()
				m.sfx.play("pearl")
				show_market(back)
			else:
				m.sfx.play("miss")
		var buy := _small_button("Buy  %d" % price, do_buy, Color("2a9d8f"), 130.0)
		var can := int(st["pearls"]) >= price and (top_left if is_top else normal_left) > 0
		_enable(buy, can)
		row.add_child(buy)
	scroll.wire(list)
