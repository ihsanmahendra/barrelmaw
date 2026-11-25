extends Control
## Screen manager. Every screen is built in code so the project has a single scene.
## A turn is two steps: pick a card (or skip), then press FIRE.

const BG_COLOR := Color("1d1f33")
const PANEL_COLOR := Color("4b3322")
const TEXT_COLOR := Color("fff4dc")
const MUTED_COLOR := Color("f3e3c3")
const WOOD := Color("6b4a2f")
const GOLD := Color("ffd166")
const BIG_HIT: int = 6  # barrels smashed in one action that count as a big hit (the pirate grins)
const RARITY_COLORS := {
	"common": Color("8d93b5"),
	"rare": Color("4cc9f0"),
	"epic": Color("9b5de5"),
	"legendary": Color("ffd166"),
	"transcended": Color("3de0c8"),
}
const COLOR_NAMES := {"R": "Red", "O": "Orange", "Y": "Yellow", "G": "Green", "B": "Blue",
	"P": "Purple", "K": "Dark", "W": "White", "N": "Brown", "S": "Pink"}

# Guided practice picture: a red ring around four blue blocks.
const TUTORIAL_ROWS: Array = [".RRRR.", "RRBBRR", "RRBBRR", ".RRRR."]
const TUTORIAL_QUEUE: Array = [
	{"color": "R", "ammo": 4}, {"color": "R", "ammo": 4}, {"color": "B", "ammo": 4},
	{"color": "R", "ammo": 4}, {"color": "R", "ammo": 4},
]
const TUTORIAL_HANDS: Array = [
	["power_shot", "skip", "wildcard"],
	["row_strike", "quick_draw", "reload"],
	["scatter", "power_shot", "skip"],
]
# Each step: text, advance_on ("next" button, "card" played or "fire" pressed), what to outline,
# which card may be tapped ("" none, "*" any) and whether FIRE works.
const TUTORIAL_STEPS: Array = [
	{"text": "Welcome! Your goal: remove every colored barrel from the board.", "advance": "next", "look": "board", "card": "", "fire": false},
	{"text": "These are your cannonballs. The NEXT one goes into the cannon first. It only hits barrels of its own color, and the number is how many it smashes.", "advance": "next", "look": "queue", "card": "", "fire": false},
	{"text": "Each turn you may play ONE card. Tap Power Shot to preview what it does.", "advance": "card", "look": "card", "card": "power_shot", "fire": false},
	{"text": "Power Shot added +2 hits. The white outlines show the barrels that will be removed. Now press FIRE!", "advance": "fire", "look": "fire", "card": "", "fire": true},
	{"text": "Nice! Some cards clear more than one barrel per hit. Tap Row Strike to preview it: each hit clears a whole row of its color.", "advance": "card", "look": "card", "card": "row_strike", "fire": false},
	{"text": "Outlined barrels are what will go. Press FIRE!", "advance": "fire", "look": "fire", "card": "", "fire": true},
	{"text": "Last cannonball: blue. Pick any card (or skip), then press FIRE to finish the picture.", "advance": "fire", "look": "none", "card": "*", "fire": true},
]

var battle: Battle
var stage: int = 0  # index of the stage being played (0-19)
var _stage_deck: Array = []
var _prev_best: int = 0
var map_view: MapView
var map_scroll: ScrollContainer
var popup: Control
var deck_view: DeckView
var beach: BeachBackground
var _on_menu: bool = false
var _menu_extras: Array = []  # nodes added for the menu only (gulls, version label), freed with the screen
var gear_button: Button
var options_layer: Control
var _options_holder: CenterContainer
var _quit_armed: bool = false
var _last_special_sfx: Dictionary = {}
var _removed_note: String = ""  # shown in the hint panel after cannonballs were removed, until the next action
var _intro_queue: Array = []  # special kinds that triggered for the first time during the latest action
var _intro_open: Control

signal _intro_closed
var _overlay_layer: CanvasLayer
var _menu_stage: PirateStage
var packs: PackScreens  # Treasury, chest opening, Cargo Hold, Port Market
var _last_rewards: Dictionary = {}  # what the latest win paid (Doubloons and chests), for the results screen
var screen: Control
var board_view: BoardView
var queue_view: QueueView
var hand_box: HBoxContainer
var hint_label: Label
var hud: HudView
var draw_icon: PileIcon
var discard_icon: PileIcon
var _battle_title: String = ""
var fire_button: Button
var highlight: Highlight
var sfx: Sfx
var music: Music
var mute_button: Button
var busy: bool = false
var selected: int = -1  # index in hand of the card being previewed, or -1
var _preview: Dictionary = {}
var _seen_drawn: int = 0
var _deal_delay: float = 0.0

# Tutorial state.
var tutorial: bool = false
var tut_step: int = 0
var tut_label: Label
var tut_next: Button


func _ready() -> void:
	GameData.ensure_loaded()
	beach = BeachBackground.new()
	add_child(beach)
	sfx = Sfx.new()
	add_child(sfx)
	music = Music.new()
	add_child(music)
	highlight = Highlight.new()
	add_child(highlight)
	_make_mute_button()
	packs = PackScreens.new(self)
	var args := OS.get_cmdline_user_args()
	var debug_stage := 0
	for a in args:  # debug flags: --progress=N (fake clears), --stage=N (1-based)
		if a.begins_with("--progress="):
			SaveData.path = "user://debug_save.cfg"
			SaveData.reset()
			SaveData.tutorial_done = true
			for k in int(a.get_slice("=", 1)):
				SaveData.record(k, 1 + (k * 7) % 3)
			if not args.has("--fresh-specials"):  # debug runs skip the first-time pop-ups
				for kind in Board.SPECIALS:
					SaveData.mark_special_seen(kind)
		if a.begins_with("--stage="):
			debug_stage = int(a.get_slice("=", 1)) - 1
	for a in args:  # debug: --packs=N gives N of every chest, Doubloons, Pearls, some spare copies and the Transcended cards
		if a.begins_with("--packs="):
			if not args.has("--progress=" + str(a.get_slice("=", 1))) and SaveData.path != "user://debug_save.cfg":
				SaveData.path = "user://debug_save.cfg"
				SaveData.reset()
				SaveData.tutorial_done = true
			_debug_packs(int(a.get_slice("=", 1)))
	if args.has("--gift"):
		SaveData.reset()
		SaveData.tutorial_done = true
	if args.has("--giftplay"):  # debug: claim a gift, then start stage 1 and print what the deck holds
		SaveData.path = "user://debug_save.cfg"
		SaveData.reset()
		SaveData.claim_daily("blast")
		var base := Stages.deck_for(0).size()
		_begin_stage(0, Stages.deck_for(0))
		print("GIFTPLAY deck=", _stage_deck.size(), " base=", base, " has_blast=", _stage_deck.has("blast"), " pending_after=", SaveData.pending_gift())
		_begin_stage(1, Stages.deck_for(1))
		print("GIFTPLAY second stage deck=", _stage_deck.size(), " base=", Stages.deck_for(1).size())
		return
	if args.has("--treasury"):
		packs.show_treasury()
	elif args.has("--cargo"):
		var filter := "all"
		for a in args:
			if a.begins_with("--filter="):
				filter = a.get_slice("=", 1)
		packs.show_cargo(Callable(), filter)
		for a in args:
			if a.begins_with("--detail="):
				packs._show_detail(a.get_slice("=", 1))
	elif args.has("--market"):
		packs.show_market()
	elif args.has("--claim-crate"):  # debug: claim the daily crate and open it
		_claim_daily_crate()
	elif args.has("--opening"):
		for a in args:
			if a.begins_with("--open-chest="):
				packs.open_and_show(a.get_slice("=", 1))
	elif args.has("--howto"):
		show_howto()
	elif args.has("--settings"):
		show_menu()
		await get_tree().create_timer(0.3).timeout
		_open_options()
	elif args.has("--giftpopup"):
		show_menu()
		await get_tree().create_timer(0.3).timeout
		_claim_daily_gift()
	elif args.has("--map"):
		show_map()
		if args.has("--map-top"):
			await get_tree().create_timer(0.3).timeout
			map_scroll.scroll_vertical = 0
	elif args.has("--popup"):
		show_map()
		_open_popup(debug_stage)
	elif args.has("--unlock"):
		stage = debug_stage
		show_unlock(debug_stage)
	elif args.has("--result") or args.has("--lose"):
		stage = debug_stage
		_stage_deck = Stages.deck_for(stage)
		battle = Stages.new_battle(stage, _stage_deck, 1)
		battle.queue = [{"color": "R", "ammo": 9}]
		battle.over = true
		battle.won = args.has("--result")
		_prev_best = 1
		if args.has("--rewards"):  # debug: show what a win can pay
			_last_rewards = {"doubloons": 100, "chests": {"iron": 2, "crate": 1}}
		show_stage_result(battle.won)
	elif args.has("--tutorial"):
		start_tutorial()
		if args.has("--autoplay"):  # debug: walk through the tutorial for screenshots
			await get_tree().create_timer(0.5).timeout
			_tut_next_pressed()
			_tut_next_pressed()
			await get_tree().create_timer(1.0).timeout
			_on_card_pressed(0)
			await get_tree().create_timer(1.0).timeout
			_on_fire_pressed()
	elif args.has("--autostart"):
		_begin_stage(debug_stage, Stages.deck_for(debug_stage))
		if args.has("--specials-demo"):  # debug: a bomb next to the first target, so one shot shows the blast
			await get_tree().create_timer(0.3).timeout
			var tgt: Vector2i = battle.preview_targets()[0]
			battle.board.set_special(tgt.x, tgt.y, "bomb")  # the first cannonball lands right on a bomb
			board_view.set_battle(battle)
			_refresh()
			await get_tree().create_timer(0.3).timeout
			_on_fire_pressed()
			if args.has("--close-intro"):  # debug: dismiss the pop-up by emitting its signal, then play on
				await get_tree().create_timer(3.0).timeout
				_intro_closed.emit()
				await get_tree().create_timer(1.0).timeout
				print("RESUMED busy=", busy, " intro_open=", _intro_open != null)
		if args.has("--prune-demo"):  # debug: leave a single barrel of the front color, so firing clears the color
			await get_tree().create_timer(0.3).timeout
			var col: String = battle.queue[0]["color"]
			battle.queue.insert(2, {"color": col, "ammo": 3})  # leftovers that will have nothing to hit
			battle.queue.insert(3, {"color": col, "ammo": 2})
			var keep := false
			for y in battle.board.h:
				for x in battle.board.w:
					if battle.board.get_c(x, y) == col:
						if keep:
							battle.board.remove_at(x, y)
						else:
							keep = true
			board_view.set_battle(battle)
			_refresh()
			await get_tree().create_timer(0.3).timeout
			_on_fire_pressed()
		if args.has("--botplay"):  # debug: an auto-player that plays whole stages through the real screens
			await get_tree().create_timer(0.5).timeout
			var guard := 0
			while screen != null and battle != null and not battle.over and guard < 60:
				guard += 1
				while busy:
					await get_tree().create_timer(0.1).timeout
				var best := -1
				var bs := -1.0
				for i in battle.hand.size():
					var s := 0.0
					for e in GameData.cards[battle.hand[i]]["effects"]:
						if ["ammo", "clear_random", "clear_color", "shape", "wild", "double"].has(e["kind"]):
							s += 3.0
					if s > bs:
						bs = s
						best = i
				if best >= 0 and randf() < 0.6:
					_on_card_pressed(best)
					_on_fire_pressed()  # confirms the previewed card
					while busy:
						await get_tree().create_timer(0.1).timeout
				if not battle.over:
					_on_fire_pressed()
				while busy:
					await get_tree().create_timer(0.1).timeout
			print("BOTPLAY done: won=", battle.won, " turns=", battle.turns)
		if args.has("--win-demo"):  # debug: clear the whole board and play the win celebration
			await get_tree().create_timer(0.4).timeout
			for y in battle.board.h:
				for x in battle.board.w:
					battle.board.remove_at(x, y)
			_refresh()
			board_view.celebrate()
		if args.has("--cheer"):
			await get_tree().create_timer(0.5).timeout
			queue_view.cheer(8)  # debug: show the grin without having to land a big hit
		for a in args:  # debug: --intro=bomb|ammo|iron|curse shows that first-time pop-up
			if a.begins_with("--intro="):
				await get_tree().create_timer(0.4).timeout
				_show_special_intro(a.get_slice("=", 1))
		if args.has("--options"):
			await get_tree().create_timer(0.4).timeout
			_open_options()
			if args.has("--howto-view"):
				_options_show("howto")
		for a in args:  # debug: --hand=N forces a hand of N cards to check card layout
			if a.begins_with("--hand="):
				var forced: Array = ["column_strike", "color_bomb", "wild_cross", "overclock", "pierce_blast", "double_blast"]
				var spec := a.get_slice("=", 1)
				if spec.is_valid_int():
					battle.hand = forced.slice(0, int(spec))
				else:  # --hand=card_a,card_b names the cards
					battle.hand = Array(spec.split(",", false))
				_seen_drawn = battle.drawn_total
				_refresh()
		if args.has("--autoplay"):
			await get_tree().create_timer(0.4).timeout
			var pick := 0
			for k in battle.hand.size():
				if ["scatter", "pick_off", "color_bomb", "tidy_up"].has(battle.hand[k]):
					pick = k  # debug: prefer a card that removes barrels itself
			_on_card_pressed(pick)
			await get_tree().create_timer(1.2).timeout
			_on_fire_pressed()
			await get_tree().create_timer(1.6).timeout
			_on_fire_pressed()
	else:
		show_menu()


# ---------- helpers ----------

func _make_mute_button() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	mute_button = Button.new()
	mute_button.text = "Sound on"
	mute_button.focus_mode = Control.FOCUS_NONE
	mute_button.flat = true
	mute_button.add_theme_font_size_override("font_size", 16)
	mute_button.add_theme_color_override("font_color", Color.WHITE)
	mute_button.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.05, 0.9))
	mute_button.add_theme_constant_override("outline_size", 4)
	mute_button.position = Vector2(8, 4)
	mute_button.pressed.connect(_toggle_mute)
	layer.add_child(mute_button)
	# Options (gear) button, shown on the battle screen only.
	gear_button = Button.new()
	gear_button.focus_mode = Control.FOCUS_NONE
	gear_button.flat = true
	gear_button.visible = false
	gear_button.anchor_left = 1.0
	gear_button.anchor_right = 1.0
	gear_button.offset_left = -58.0
	gear_button.offset_right = -10.0
	gear_button.offset_top = 3.0
	gear_button.offset_bottom = 51.0
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		gear_button.add_theme_stylebox_override(state, empty)
	gear_button.draw.connect(_draw_gear)
	gear_button.pressed.connect(_open_options)
	layer.add_child(gear_button)
	_overlay_layer = CanvasLayer.new()  # options menu sits above everything
	_overlay_layer.layer = 20
	add_child(_overlay_layer)


func _toggle_mute() -> void:
	Sfx.muted = not Sfx.muted
	mute_button.text = "Sound off" if Sfx.muted else "Sound on"
	music.refresh()
	sfx.play("click")


## Wooden square with a gear icon.
func _draw_gear() -> void:
	var b := gear_button
	var pressed := b.is_pressed() and b.is_hovered()
	b.draw_style_box(UiKit.plank_style(WOOD, pressed), Rect2(Vector2.ZERO, b.size))
	var c := b.size / 2.0 + Vector2(0, -2)
	for k in 8:
		var a := float(k) * TAU / 8.0
		var d := Vector2(cos(a), sin(a))
		var n := Vector2(-d.y, d.x)
		b.draw_colored_polygon(PackedVector2Array([c + d * 9.0 + n * 4.0, c + d * 14.0 + n * 3.0, c + d * 14.0 - n * 3.0, c + d * 9.0 - n * 4.0]), UiKit.CREAM)
	b.draw_circle(c, 10.5, UiKit.CREAM)
	b.draw_circle(c, 4.5, WOOD.darkened(0.2))


func _new_screen(separation: int = 12) -> VBoxContainer:
	highlight.clear()
	_close_options()
	gear_button.visible = false
	mute_button.visible = true
	music.play_track("menu")
	if deck_view != null and is_instance_valid(deck_view):
		deck_view.queue_free()
	deck_view = null
	_on_menu = false
	for n in _menu_extras:
		if is_instance_valid(n):
			n.queue_free()
	_menu_extras.clear()
	if beach != null:
		beach.modulate = Color.WHITE
	PirateArt.night_tint = Color.WHITE
	if screen != null:
		screen.queue_free()
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	margin.add_theme_constant_override("margin_top", 30)  # room for the sound toggle
	add_child(margin)
	move_child(highlight, get_child_count() - 1)  # keep outlines above the screen
	screen = margin
	margin.modulate.a = 0.0
	create_tween().tween_property(margin, "modulate:a", 1.0, 0.22)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	margin.add_child(box)
	return box


func _label(text: String, size: int = 20, color: Color = TEXT_COLOR, align: int = HORIZONTAL_ALIGNMENT_CENTER, bold: bool = false, outlined: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align as HorizontalAlignment
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", UiKit.bold_font())
	if outlined:
		l.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.05, 0.9))
		l.add_theme_constant_override("outline_size", 8 if size >= 40 else (6 if size >= 18 else 4))
	return l


func _box_style(color: Color, border: Color = Color.TRANSPARENT, border_w: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(18)
	s.set_border_width_all(border_w)
	s.border_color = border
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


func _set_button_color(b: Button, color: Color) -> void:
	b.add_theme_stylebox_override("normal", UiKit.plank_style(color))
	b.add_theme_stylebox_override("hover", UiKit.plank_style(color.lightened(0.1)))
	b.add_theme_stylebox_override("pressed", UiKit.plank_style(color.darkened(0.1), true))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _button(text: String, callback: Callable, color: Color = Color("ef476f")) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 66)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 25)
	b.add_theme_font_override("font", UiKit.bold_font())
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.03, 0.8))
	b.add_theme_constant_override("outline_size", 5)
	_set_button_color(b, color)
	b.pressed.connect(func() -> void: sfx.play("click"))
	b.pressed.connect(callback)
	return b


func _spacer() -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


func _card_button(id: String, callback: Callable, level: int = 1) -> Button:
	var card_view := CardView.new().setup(id).set_level(level)
	card_view.pressed.connect(callback)
	return card_view


# ---------- settings ----------

# ---------- menu and info screens ----------

## Hour of day (0-24) used for the menu's sky tint; --hour=N overrides it for testing.
func _menu_hour() -> float:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--hour="):
			return float(a.get_slice("=", 1))
	var d := Time.get_time_dict_from_system()
	return float(d["hour"]) + float(d["minute"]) / 60.0


## Color that tints the beach picture: warm at dawn and dusk, dark blue at night.
func _tod_color(h: float) -> Color:
	var night := Color(0.34, 0.42, 0.74)
	var warm := Color(1.0, 0.8, 0.66)
	if h < 5.0 or h >= 20.0:
		return night
	if h < 7.0:
		return night.lerp(warm, (h - 5.0) / 2.0) if h < 6.0 else warm.lerp(Color.WHITE, h - 6.0)
	if h < 17.0:
		return Color.WHITE
	if h < 19.0:
		return Color.WHITE.lerp(warm, (h - 17.0) / 2.0)
	return warm.lerp(night, h - 19.0)


func show_menu() -> void:
	tutorial = false
	var box := _new_screen(10)
	_on_menu = true
	gear_button.visible = true  # settings
	mute_button.visible = false
	music.play_track("menu")
	# Sky: tinted by the time of day, with gulls, water glints and (at night) stars and a moon.
	var hour := _menu_hour()
	beach.modulate = _tod_color(hour)
	var life := SkyLife.new()
	life.night = hour < 5.5 or hour >= 19.5
	add_child(life)
	move_child(life, 1)
	_menu_extras.append(life)
	var logo := FlatLogo.new()
	logo.custom_minimum_size = Vector2(0, 150)
	box.add_child(logo)
	var stage_view := PirateStage.new()
	stage_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_view.custom_minimum_size = Vector2(0, 250)
	stage_view.tapped.connect(func() -> void: sfx.play("cannon"))
	box.add_child(stage_view)
	_menu_stage = stage_view
	deck_view = DeckView.new()
	add_child(deck_view)
	move_child(deck_view, 1)
	# Next goal.
	var all_done := SaveData.cleared_count() >= Stages.TOTAL
	var next_index := mini(SaveData.highest_unlocked(), Stages.TOTAL - 1)
	var plaque := MenuPlaque.new()
	plaque.set_info(next_index, String(Stages.picture(next_index)["name"]), SaveData.total_stars(), Stages.TOTAL * 3, all_done, SaveData.pending_gift())
	box.add_child(plaque)
	# Daily crate, shown only while it is waiting to be claimed.
	if Rewards.daily_available(SaveData.pack_state(), SaveData.today()):
		var gift_btn := _button("Claim your daily crate", _claim_daily_crate, Color("e0a020"))
		gift_btn.custom_minimum_size = Vector2(0, 52)
		gift_btn.add_theme_font_size_override("font_size", 21)
		box.add_child(gift_btn)
	# Treasury and Cargo Hold, with a red dot when something is waiting.
	var pack_row := HBoxContainer.new()
	pack_row.add_theme_constant_override("separation", 8)
	var st_packs := SaveData.pack_state()
	var treasury_btn := _button("Treasury", func() -> void: packs.show_treasury(), Color("2a9d8f"))
	treasury_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	treasury_btn.custom_minimum_size = Vector2(0, 52)
	treasury_btn.add_theme_font_size_override("font_size", 21)
	if packs.openable_count() > 0 or not (st_packs["pending"] as Array).is_empty():
		_add_red_dot(treasury_btn)
	pack_row.add_child(treasury_btn)
	var cargo_btn := _button("Cargo Hold", func() -> void: packs.show_cargo(), Color("6a4c93"))
	cargo_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cargo_btn.custom_minimum_size = Vector2(0, 52)
	cargo_btn.add_theme_font_size_override("font_size", 21)
	if Collection.ready_count(st_packs, GameData.cards) > 0:
		_add_red_dot(cargo_btn)
	pack_row.add_child(cargo_btn)
	box.add_child(pack_row)
	var play := _button("Play" if SaveData.cleared_count() == 0 else "Continue", _on_play_pressed)
	play.custom_minimum_size = Vector2(0, 84)
	play.add_theme_font_size_override("font_size", 34)
	box.add_child(play)
	# How to play is a small text link, not a second big button.
	var link := Button.new()
	link.text = "How to play"
	link.flat = true
	link.focus_mode = Control.FOCUS_NONE
	link.custom_minimum_size = Vector2(0, 38)
	link.add_theme_font_size_override("font_size", 19)
	link.add_theme_font_override("font", UiKit.bold_font())
	for st in ["font_color", "font_hover_color", "font_pressed_color"]:
		link.add_theme_color_override(st, UiKit.CREAM)
	link.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.03, 0.95))
	link.add_theme_constant_override("outline_size", 6)
	link.pressed.connect(func() -> void:
		sfx.play("click")
		show_howto())
	box.add_child(link)
	# Version number, small and faint in the corner.
	var ver := Label.new()
	ver.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", "0.1.0"))
	ver.add_theme_font_size_override("font_size", 13)
	ver.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	ver.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	ver.add_theme_constant_override("outline_size", 3)
	ver.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ver.z_index = 5
	add_child(ver)
	ver.anchor_left = 1.0
	ver.anchor_right = 1.0
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_left = -70.0
	ver.offset_right = -10.0
	ver.offset_top = -22.0
	ver.offset_bottom = -4.0
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_menu_extras.append(ver)
	_sync_menu_deck()


## A small red dot on the top right of a button: something is waiting there.
func _add_red_dot(b: Button) -> void:
	var dot := Panel.new()
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.add_theme_stylebox_override("panel", UiKit.panel_style(Color("e63946"), Color.WHITE, 3, 12))
	dot.custom_minimum_size = Vector2(24, 24)
	dot.size = Vector2(24, 24)
	dot.anchor_left = 1.0
	dot.anchor_right = 1.0
	dot.offset_left = -26.0
	dot.offset_right = -2.0
	dot.offset_top = -6.0
	dot.offset_bottom = 18.0
	b.add_child(dot)


## Claims today's crate and opens it at once (or tells the player where it is waiting if it cannot be opened yet).
func _claim_daily_crate() -> void:
	var st := SaveData.pack_state()
	var chest := Rewards.daily_claim(st, SaveData.today())
	if chest == "":
		return
	SaveData.save()
	sfx.play("sparkle")
	if Packs.is_unlocked(chest, SaveData.highest_unlocked()):
		packs.open_and_show(chest)
	else:
		_toast("%s saved in the Treasury. It opens after stage %d." % [PackConfig.chest(chest)["name"], int(PackConfig.chest(chest)["unlock_cleared"])], 2.6)
		show_menu()


## Lines the menu's deck up with the pirate once the layout is known.
func _sync_menu_deck() -> void:
	await get_tree().process_frame
	if deck_view == null or not is_instance_valid(deck_view) or _menu_stage == null or not is_instance_valid(_menu_stage):
		return
	deck_view.top_y = _menu_stage.global_position.y + _menu_stage.size.y - 108.0
	deck_view.pivot = Vector2(size.x / 2.0, deck_view.top_y + 140.0)
	_menu_stage.ship_pivot = deck_view.pivot


func _on_play_pressed() -> void:
	if SaveData.tutorial_done:
		show_map()
	else:
		start_tutorial()


## The four how-to steps as rows (badge, title, text), used by the how-to screen and the options menu.
func _add_howto_rows(inner: VBoxContainer) -> void:
	var steps: Array = [
		["1", "Clear the picture", "Smash every colored barrel before you run out of cannonballs."],
		["2", "Mind the queue", "The NEXT cannonball goes into the cannon first. It smashes barrels of its own color; the number is how many."],
		["3", "Preview a card", "Tap a card to see what it does. Press Play to use it, or tap it again to cancel."],
		["4", "Press FIRE", "White outlines show what will smash. Finish within the turn limit to earn 3 stars."],
		["5", "Special barrels", "Bombs blow up neighbors and crates give a cannonball. Iron takes two hits and skulls weaken your next cannonball."],
	]
	var step_index := 0
	for s in steps:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var badge := _label(s[0], 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
		badge.custom_minimum_size = Vector2(50, 50)
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_stylebox_override("normal", UiKit.panel_style(Color("d62839"), Color("8f1d28"), 3, 25))
		row.add_child(badge)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(_label(s[1], 20, UiKit.INK, HORIZONTAL_ALIGNMENT_LEFT, true, false))
		col.add_child(_label(s[2], 15, Color("6b4a2f"), HORIZONTAL_ALIGNMENT_LEFT, false, false))
		row.add_child(col)
		var art := HowtoArt.new(step_index)
		art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(art)
		step_index += 1
		inner.add_child(row)


func show_howto() -> void:
	tutorial = false
	var box := _new_screen()
	var how_ribbon := RibbonLabel.new("How to play", 40)
	how_ribbon.custom_minimum_size = Vector2(0, 110)
	box.add_child(how_ribbon)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.parchment_style())
	box.add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 14)
	panel.add_child(inner)
	_add_howto_rows(inner)
	box.add_child(_spacer())
	box.add_child(_button("Play the guided practice", start_tutorial))
	box.add_child(_button("Back", show_menu, WOOD))


# ---------- battle screen ----------

func start_tutorial() -> void:
	tutorial = true
	tut_step = 0
	battle = Battle.new(TUTORIAL_ROWS, GameData.starter_deck, 1.0, GameData.hand_size, 1,
		{"queue": TUTORIAL_QUEUE, "hands": TUTORIAL_HANDS})
	_build_battle_screen("Practice")
	_tut_show()


## Card levels for a battle: the player's merged levels, or every card at N with the debug flag --levels=N.
func _battle_levels() -> Dictionary:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--levels="):
			var lv := clampi(int(a.get_slice("=", 1)), 1, PackConfig.max_level())
			var all := {}
			for id in GameData.card_order:
				all[id] = lv
			return all
	return Collection.levels_for_battle(SaveData.pack_state())


## Debug: fills the pack state so every screen has something to show (--packs=N).
func _debug_packs(n: int) -> void:
	var st := SaveData.pack_state()
	for c in PackConfig.chests:
		Packs.grant(st, str(c["id"]), n)
	st["doubloons"] = 4000
	st["pearls"] = 120
	for id in ["power_shot", "row_strike", "scatter", "cross_strike", "blast", "prism"]:
		st["spare"][id] = 2
	st["level"]["power_shot"] = 2
	st["level"]["blast"] = 3
	for id in GameData.card_order:
		if GameData.cards[id]["rarity"] == "transcended":
			Collection.add_copy(st, id, GameData.cards)
	st["welcome_given"] = true
	SaveData.save()


## Starts a stage with the given deck (see Stages.deck_for).
func _begin_stage(index: int, deck: Array) -> void:
	tutorial = false
	stage = index
	deck = Collection.deck_with_equipped(deck, SaveData.pack_state(), SaveData.highest_unlocked(), GameData.cards)
	for a in OS.get_cmdline_user_args():
		if a == "--tcards":  # debug: all four Transcended cards in the deck
			for id in GameData.card_order:
				if GameData.cards[id]["rarity"] == "transcended":
					deck.append(id)
	var gift := SaveData.take_pending_gift()
	if gift != "":
		deck.append(gift)
	_stage_deck = deck.duplicate()
	_prev_best = SaveData.stars(index)
	battle = Stages.new_battle(index, deck, randi(), _battle_levels())
	_build_battle_screen(Stages.title(index))
	if gift != "":
		_toast("Gift card added to your deck: %s" % String(GameData.cards[gift]["name"]), 3.5)


func _build_battle_screen(title: String) -> void:
	busy = false
	_seen_drawn = 0
	_battle_title = title
	var box := _new_screen(8)
	deck_view = DeckView.new()
	add_child(deck_view)
	move_child(deck_view, 1)  # above the beach, below the screen's controls
	if tutorial:
		var panel := PanelContainer.new()
		var ps := UiKit.parchment_style()
		ps.content_margin_top = 8
		ps.content_margin_bottom = 8
		panel.add_theme_stylebox_override("panel", ps)
		var pv := VBoxContainer.new()
		pv.add_theme_constant_override("separation", 4)
		panel.add_child(pv)
		pv.add_child(_label("Captain's tip", 14, Color("a8743f"), HORIZONTAL_ALIGNMENT_LEFT, true, false))
		tut_label = _label("", 18, UiKit.INK, HORIZONTAL_ALIGNMENT_LEFT, false, false)
		tut_label.custom_minimum_size = Vector2(0, 66)
		pv.add_child(tut_label)
		tut_next = _button("Next", _tut_next_pressed, Color("ef476f"))
		tut_next.custom_minimum_size = Vector2(0, 44)
		pv.add_child(tut_next)
		box.add_child(panel)
	hud = HudView.new()
	hud.custom_minimum_size = Vector2(0, 64 if tutorial else 110)
	box.add_child(hud)

	board_view = BoardView.new()
	board_view.custom_minimum_size = Vector2(0, 150 if tutorial else 220)
	board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_view.set_battle(battle)
	board_view.shot_launched.connect(_on_shot_launched)
	board_view.shot_landed.connect(_on_shot_landed)
	board_view.sequence_done.connect(_on_sequence_done)
	board_view.special_event.connect(_on_special_event)
	box.add_child(board_view)

	queue_view = QueueView.new()
	queue_view.custom_minimum_size = Vector2(0, 138 if tutorial else 150)
	queue_view.set_battle(battle)
	box.add_child(queue_view)

	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 8)
	draw_icon = PileIcon.new()
	draw_icon.caption = "Draw"
	draw_icon.custom_minimum_size = Vector2(70, 58)
	info_row.add_child(draw_icon)
	var hint_panel := PanelContainer.new()
	hint_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hs := UiKit.panel_style(Color(0.18, 0.1, 0.06, 0.84), Color("a8743f"), 3, 14)
	hs.content_margin_top = 6
	hs.content_margin_bottom = 6
	hs.content_margin_left = 8
	hs.content_margin_right = 8
	hint_panel.add_theme_stylebox_override("panel", hs)
	hint_label = _label("", 16, GOLD, HORIZONTAL_ALIGNMENT_CENTER, false, false)
	hint_label.custom_minimum_size = Vector2(0, 46)
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_panel.add_child(hint_label)
	info_row.add_child(hint_panel)
	discard_icon = PileIcon.new()
	discard_icon.caption = "Discard"
	discard_icon.back_color = Color("8d6e63")
	discard_icon.custom_minimum_size = Vector2(70, 58)
	info_row.add_child(discard_icon)
	box.add_child(info_row)

	hand_box = HBoxContainer.new()
	hand_box.add_theme_constant_override("separation", 10)
	box.add_child(hand_box)

	fire_button = _button("Skip card, just fire", _on_fire_pressed, WOOD)
	box.add_child(fire_button)
	gear_button.visible = true
	mute_button.visible = false  # the options menu has the sound switch
	var night_stage := not tutorial and Stages.is_night(stage)
	music.play_track("night" if night_stage else "battle")
	if night_stage:
		_apply_night_look()
	_refresh()
	await get_tree().process_frame
	_sync_deck()


func _refresh() -> void:
	_update_status()
	for c in hand_box.get_children():
		c.queue_free()
	# Cards drawn since the last refresh are always the last ones in the hand.
	var new_count: int = mini(battle.drawn_total - _seen_drawn, battle.hand.size())
	_seen_drawn = battle.drawn_total
	var fresh: Array = []
	var can_play := battle.plays_left > 0 and not battle.over
	for i in battle.hand.size():
		var cb := _card_button(battle.hand[i], _on_card_pressed.bind(i), battle.level_of(battle.hand[i]))
		cb.disabled = not can_play
		hand_box.add_child(cb)
		if i >= battle.hand.size() - new_count:
			cb.modulate.a = 0.0  # hidden until the draw animation starts
			fresh.append(cb)
	if not fresh.is_empty():
		_deal_cards(fresh, _deal_delay)
		_deal_delay = 0.0
	selected = -1
	_update_preview()
	_update_fire_button()
	_update_highlight()
	draw_icon.set_count(battle.draw_pile.size())
	discard_icon.set_count(battle.discard.size())
	queue_view.queue_redraw()
	board_view.queue_redraw()


## Night stages: dark blue sky with stars and a moon, a dimmer deck and pirate, and a lantern.
func _apply_night_look() -> void:
	beach.modulate = Color(0.32, 0.4, 0.72)
	PirateArt.night_tint = Color(0.82, 0.86, 1.0)
	var life := SkyLife.new()
	life.night = true
	life.birds = false
	add_child(life)
	move_child(life, 1)
	_menu_extras.append(life)
	if deck_view != null:
		deck_view.modulate = Color(0.66, 0.72, 0.95)
	queue_view.night = true
	queue_view.queue_redraw()


## Lines the deck up with the pirate's row once the layout is known.
func _sync_deck() -> void:
	if deck_view != null and is_instance_valid(deck_view) and queue_view != null and is_instance_valid(queue_view):
		deck_view.top_y = queue_view.global_position.y + 40.0
		deck_view.pivot = Vector2(size.x / 2.0, deck_view.top_y + 140.0)
		queue_view.ship_pivot = deck_view.pivot


## Goal counters: barrels left vs hits left, so winning and losing are visible at a glance.
func _update_status() -> void:
	var blocks := battle.board.count()
	var shots := battle.shots_left()
	hud.set_state("" if tutorial else _battle_title, blocks, shots, -1 if tutorial else battle.projected_stars(), shots < blocks, battle.turns, battle.star_limit())


## Two plain lines: what the next shot does, and what to do now.
func _update_hint(will_hit: int) -> void:
	if battle.over or battle.queue.is_empty():
		hint_label.text = ""
		return
	var s: Dictionary = battle.queue[0]
	var color_name: String = "Any color" if battle.mods["wild"] else String(COLOR_NAMES.get(s["color"], "Matching"))
	if will_hit == 0:
		hint_label.text = "This cannonball has nothing to hit.\nPlay a card to fix it."
		return
	var first := "%s cannonball hits %d barrel%s." % [color_name, will_hit, "" if will_hit == 1 else "s"]
	var second := "Tap a card to preview it, or skip."
	if battle.cards_played_turn > 0:
		second = "Play another card or press FIRE." if battle.plays_left > 0 else "Now press FIRE!"
	if _removed_note != "":
		first = _removed_note  # the removal note stays until the next action
	hint_label.text = first + "\n" + second


func _update_fire_button() -> void:
	if selected >= 0 and selected < battle.hand.size():
		fire_button.text = "Play %s" % GameData.cards[battle.hand[selected]]["name"]
		_set_button_color(fire_button, Color("2a9d8f"))
	elif battle.cards_played_turn > 0:
		fire_button.text = "FIRE!"
		_set_button_color(fire_button, Color("ef476f"))
	else:
		fire_button.text = "Skip card, just fire"
		_set_button_color(fire_button, WOOD)


## Outlines what the player should look at or tap next.
func _update_highlight() -> void:
	if battle.over or busy:
		highlight.clear()
		return
	if tutorial:
		return  # the tutorial step sets its own target
	if selected >= 0 or battle.cards_played_turn > 0:
		highlight.target_fn = func() -> Variant: return fire_button
	else:
		highlight.clear()


## Tapping a card selects it and shows exactly what it would do. Tap it again to cancel.
func _on_card_pressed(i: int) -> void:
	if busy or battle.over or battle.plays_left <= 0 or i >= battle.hand.size():
		return
	if tutorial:
		var allowed: String = TUTORIAL_STEPS[tut_step]["card"]
		if allowed == "" or (allowed != "*" and allowed != battle.hand[i]):
			return
	sfx.play("click", 1.2)
	_select(-1 if selected == i else i)


func _select(i: int) -> void:
	selected = i
	_apply_selection_visuals()
	_update_preview()
	_update_fire_button()
	if tutorial:
		_tut_selection_changed()
	else:
		_update_highlight()


## Raises the selected card, dims the others.
func _apply_selection_visuals() -> void:
	for k in hand_box.get_child_count():
		var b: Control = hand_box.get_child(k)
		var chosen := k == selected
		if b is CardView:
			(b as CardView).selected = chosen
		b.pivot_offset = b.size / 2.0
		b.scale = Vector2(1.05, 1.05) if chosen else Vector2.ONE
		b.z_index = 1 if chosen else 0
		b.modulate = Color.WHITE if (chosen or selected < 0) else Color(0.78, 0.78, 0.78)


## Shows the result of the selected card (or of no card) on the board, queue and hint line.
func _update_preview() -> void:
	if selected < 0 or selected >= battle.hand.size():
		_preview = {}
		board_view.set_preview(battle.preview_targets())
		queue_view.set_battle(battle)
		_update_hint(battle.preview_targets().size())
		return
	_preview = battle.preview_card(selected)
	board_view.set_preview(_preview["targets"], _preview["card_removed"])
	queue_view.set_battle(_preview["battle"])
	var after: Battle = _preview["battle"]
	var parts: Array = []
	if not after.queue.is_empty():
		var color_name := "Any color" if after.mods["wild"] else String(COLOR_NAMES.get(after.queue[0]["color"], "Matching"))
		parts.append("%s hits %d (was %d)" % [color_name, _preview["hits_after"], _preview["hits_before"]])
	if _preview["card_removed"].size() > 0:
		parts.append("card smashes %d" % _preview["card_removed"].size())
	if _preview["drawn"] > 0:
		parts.append("draws %d" % _preview["drawn"])
	if after.plays_left > battle.plays_left - 1:
		parts.append("extra play")
	var card_name: String = GameData.cards[battle.hand[selected]]["name"]
	hint_label.text = "Preview: %s\n%s" % [card_name, ", ".join(parts) if not parts.is_empty() else "no change to the next shot"]


func _confirm_card() -> void:
	var i := selected
	if i < 0 or i >= battle.hand.size():
		return
	var played: String = battle.hand[i]
	selected = -1
	_preview = {}
	queue_view.set_battle(battle)
	_play_ghost(i, played)
	battle.play_card(i)
	var rarity: String = GameData.cards[played]["rarity"]
	sfx.play("card", 1.0 + 0.08 * ["common", "rare", "epic", "legendary", "transcended"].find(rarity))
	if rarity == "epic" or rarity == "legendary" or rarity == "transcended":
		_flash(RARITY_COLORS[rarity])
		sfx.play("sparkle", 1.0, 0.05)
	_after_action("card")


func _on_fire_pressed() -> void:
	if busy or battle.over:
		return
	if selected >= 0:
		_confirm_card()
		return
	if tutorial and not TUTORIAL_STEPS[tut_step]["fire"]:
		return
	battle.fire()
	_after_action("fire")


func _after_action(kind: String) -> void:
	busy = true
	_removed_note = ""
	highlight.clear()
	var origin := _shooter_origin()
	var duration := board_view.play_shots(origin)
	_deal_delay = duration * 0.6
	_refresh()
	if duration > 0.0:
		await get_tree().create_timer(duration).timeout
	while not _intro_queue.is_empty():
		var kind_seen: String = _intro_queue.pop_front()
		await get_tree().create_timer(0.25).timeout
		await _show_special_intro(kind_seen)
	_announce_removed_balls()
	if battle.over:
		if battle.won:
			board_view.celebrate()
			sfx.play("win", 1.0, 0.1)
			for k in 6:  # doubloons clinking while they fall
				sfx.play("reward", 1.2 + 0.07 * (k % 3), 0.17 + 0.23 * k)
			sfx.play("boom", 0.8, 1.35)
			sfx.play("hit", 0.7, 1.35)  # the stamp lands
		await get_tree().create_timer(2.9 if battle.won else 0.8).timeout
		_on_battle_over()
		return
	busy = false
	if tutorial:
		_tut_event(kind)
	else:
		_update_highlight()


## Where bullets leave from: the front shooter, in board-local pixels.
func _shooter_origin() -> Vector2:
	return queue_view.global_position + queue_view.muzzle_local() - board_view.global_position


func _on_shot_launched(index: int, kind: String) -> void:
	if kind == "card":
		sfx.play("fire", 1.35)
		return
	var color_letter: String = battle.shots_last[index]["color"]
	queue_view.kick(color_letter, index == 0)
	if index == 0:
		sfx.play("cannon")
	else:
		sfx.play("fire", minf(1.4, 1.0 + 0.03 * index))


func _on_shot_landed(index: int, count: int) -> void:
	sfx.play("hit", minf(1.6, 0.85 + 0.04 * index + 0.03 * count))


## When a color is cleared, its leftover cannonballs are removed. Show them leaving and say why.
func _announce_removed_balls() -> void:
	if tutorial or battle.pruned_balls_last.is_empty():
		return
	var colors := {}
	var hits := 0
	for s in battle.pruned_balls_last:
		colors[s["color"]] = true
		hits += int(s["ammo"])
	queue_view.show_removed(battle.pruned_balls_last)
	var names: Array = []
	for k in colors:
		names.append(String(COLOR_NAMES.get(k, "That color")).to_lower())
	var n := battle.pruned_balls_last.size()
	var text := "No %s barrels left, so %d unused cannonball%s (%d hit%s) %s removed." % [" or ".join(names), n, "" if n == 1 else "s", hits, "" if hits == 1 else "s", "was" if n == 1 else "were"]
	# Two places so it cannot be missed: a banner that stays for a few seconds, and a note in the hint
	# panel under the cannonballs that stays until the next action.
	_removed_note = "%d unused cannonball%s removed: no %s barrels left." % [n, "" if n == 1 else "s", " or ".join(names)]
	_toast(text, 4.5)
	hint_label.text = _removed_note + "\n" + hint_label.text.get_slice("\n", 1)
	battle.pruned_balls_last = []


func _on_special_event(kind: String) -> void:
	if not SaveData.special_seen(kind) and not _intro_queue.has(kind):
		_intro_queue.append(kind)  # explained once the shots have finished landing
	var now := Time.get_ticks_msec()
	if now - int(_last_special_sfx.get(kind, 0)) < 140:
		return  # a chain of bombs should not stack into one deafening noise
	_last_special_sfx[kind] = now
	match kind:
		"bomb":
			sfx.play("boom", 1.1)
		"ammo":
			sfx.play("reward", 1.25)
		"curse":
			sfx.play("miss", 0.75)
		"iron":
			sfx.play("hit", 0.55)


func _on_sequence_done(total: int) -> void:
	if total >= BIG_HIT:
		queue_view.cheer(total)
	if total >= 12:
		sfx.play("boom")
	elif total >= 6:
		sfx.play("big")


# ---------- tutorial ----------

func _tut_show() -> void:
	var step: Dictionary = TUTORIAL_STEPS[tut_step]
	tut_label.text = step["text"]
	tut_next.visible = step["advance"] == "next"
	match step["look"]:
		"board":
			highlight.target_fn = func() -> Variant: return board_view
		"queue":
			highlight.target_fn = func() -> Variant: return queue_view
		"fire":
			highlight.target_fn = func() -> Variant: return fire_button
		"card":
			var wanted: String = step["card"]
			highlight.target_fn = func() -> Variant:
				if selected >= 0 and selected < battle.hand.size() and battle.hand[selected] == wanted:
					return fire_button  # previewing the right card: now point at the Play button
				for i in battle.hand.size():
					if battle.hand[i] == wanted and i < hand_box.get_child_count():
						return hand_box.get_child(i)
				return null
		_:
			highlight.clear()


## While a card is previewed the tutorial explains the preview; deselecting restores the step text.
func _tut_selection_changed() -> void:
	if TUTORIAL_STEPS[tut_step]["card"] == "":
		return
	if selected >= 0:
		tut_label.text = "This is a preview. Outlines show what would be hit. Press Play to use the card, or tap the card again to cancel."
	else:
		_tut_show()


func _tut_next_pressed() -> void:
	tut_step += 1
	_tut_show()


func _tut_event(kind: String) -> void:
	if TUTORIAL_STEPS[tut_step]["advance"] == kind and tut_step < TUTORIAL_STEPS.size() - 1:
		tut_step += 1
		_tut_show()


func _on_tutorial_over() -> void:
	if battle.won:
		SaveData.mark_tutorial_done()
		var box := _new_screen()
		box.add_child(_spacer())
		_result_panel(box, "You cleared it!", "That is the whole game: pick a card, check the outlines, press FIRE.\n\nSail the map: 100 stages, day and night, with stars for finishing fast.")
		box.add_child(_button("To the treasure map", func() -> void: show_map(), Color("ef476f")))
		box.add_child(_button("Practice again", start_tutorial, WOOD))
		box.add_child(_spacer())
	else:
		start_tutorial()


## Parchment card with a big title and a short message, used by result screens.
func _result_panel(box: VBoxContainer, title: String, body: String) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.parchment_style())
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	panel.add_child(inner)
	inner.add_child(_label(title, 40, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true, false))
	inner.add_child(_label(body, 20, Color("6b4a2f"), HORIZONTAL_ALIGNMENT_CENTER, false, false))
	box.add_child(panel)


# ---------- animation helpers ----------

## Cards fly from the draw pile into their hand slots, one after another.
func _deal_cards(cards: Array, wait: float = 0.0) -> void:
	await get_tree().process_frame  # wait for the container to lay the cards out
	if wait > 0.0:
		await get_tree().create_timer(wait).timeout
	var origin := draw_icon.global_position + draw_icon.size / 2.0
	for k in cards.size():
		var raw: Variant = cards[k]
		if not is_instance_valid(raw):
			continue  # the screen was rebuilt while waiting
		var c: Control = raw
		var final_pos := c.global_position
		var delay := 0.09 * k
		c.pivot_offset = c.size / 2.0
		c.global_position = origin - c.size / 2.0
		c.rotation = deg_to_rad(-20.0 + 8.0 * k)
		c.scale = Vector2(0.3, 0.3)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(c, "modulate:a", 1.0, 0.08).set_delay(delay)
		tw.tween_property(c, "global_position", final_pos, 0.38).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "rotation", 0.0, 0.38).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "scale", Vector2.ONE, 0.38).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		sfx.play("deal", 1.0 + 0.07 * k, delay)


## A copy of the played card flies up to the board and fades out.
func _play_ghost(index: int, id: String) -> void:
	if index >= hand_box.get_child_count():
		return
	var src: Control = hand_box.get_child(index)
	var ghost := _card_button(id, func() -> void: pass)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ghost)
	ghost.size = src.size
	ghost.global_position = src.global_position
	ghost.pivot_offset = src.size / 2.0
	var target := board_view.global_position + board_view.size / 2.0 - src.size / 2.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(ghost, "global_position", target, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(ghost, "scale", Vector2(0.4, 0.4), 0.28).set_ease(Tween.EASE_IN)
	tw.tween_property(ghost, "modulate:a", 0.0, 0.28).set_delay(0.08)
	tw.chain().tween_callback(ghost.queue_free)


## Brief full-screen color flash for strong cards and picture clears.
func _flash(color: Color) -> void:
	var rect := ColorRect.new()
	rect.color = Color(color.r, color.g, color.b, 0.35)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	var tw := create_tween()
	tw.tween_property(rect, "color:a", 0.0, 0.35)
	tw.tween_callback(rect.queue_free)


# ---------- results ----------

func _on_battle_over() -> void:
	if tutorial:
		_on_tutorial_over()
		return
	_last_rewards = {}
	if battle.won:
		var stars_earned := battle.star_rating()
		var before_stars := SaveData.record(stage, stars_earned)
		_last_rewards = Rewards.stage_clear(SaveData.pack_state(), stage, before_stars, stars_earned, SaveData.best_stars(), SaveData.today())
		SaveData.save()
	show_stage_result(battle.won)


# ---------- treasure map ----------

func show_map(focus: int = -1) -> void:
	tutorial = false
	var box := _new_screen(8)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	var back := _button("Menu", show_menu, WOOD)
	back.custom_minimum_size = Vector2(110, 52)
	back.add_theme_font_size_override("font_size", 20)
	header.add_child(back)
	var title := _label("Treasure Map", 34, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var chip := Control.new()
	chip.custom_minimum_size = Vector2(110, 52)
	chip.draw.connect(func() -> void:
		var sb := UiKit.panel_style(Color(0.2, 0.12, 0.07, 0.9), Color("a8743f"), 3, 16)
		chip.draw_style_box(sb, Rect2(Vector2.ZERO, chip.size))
		UiKit.draw_star(chip, Vector2(24, chip.size.y / 2.0), 13.0, UiKit.GOLD, Color("a8651a"))
		var txt := "%d" % SaveData.total_stars()
		var f := UiKit.bold_font()
		chip.draw_string_outline(f, Vector2(46, 34), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 6, Color(0, 0, 0, 0.7))
		chip.draw_string(f, Vector2(46, 34), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UiKit.CREAM))
	header.add_child(chip)
	box.add_child(header)

	var holder := Control.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.custom_minimum_size = Vector2(0, 300)
	box.add_child(holder)
	map_scroll = ScrollContainer.new()
	map_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	map_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	holder.add_child(map_scroll)
	map_view = MapView.new()
	map_view.reward_chests = _map_reward_chests()
	map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_view.stage_tapped.connect(_on_stage_tapped)
	map_scroll.add_child(map_view)
	var frame := Control.new()  # wooden frame drawn over the scrolling map
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.draw.connect(func() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.set_corner_radius_all(20)
		sb.set_border_width_all(7)
		sb.border_color = Color("6b4a2f")
		frame.draw_style_box(sb, Rect2(Vector2.ZERO, frame.size).grow(-1.0)))
	holder.add_child(frame)
	# Button that jumps back to the current stage when it is scrolled out of view.
	var target_stage := focus if focus >= 0 else SaveData.highest_unlocked()
	var jump := _button("", func() -> void: _scroll_map_to(target_stage, true), Color("ef476f"))
	jump.custom_minimum_size = Vector2(230, 50)
	jump.add_theme_font_size_override("font_size", 19)
	jump.visible = false
	jump.anchor_left = 0.5
	jump.anchor_right = 0.5
	jump.anchor_top = 1.0
	jump.anchor_bottom = 1.0
	jump.offset_left = -115.0
	jump.offset_right = 115.0
	jump.offset_top = -70.0
	jump.offset_bottom = -20.0
	holder.add_child(jump)
	var update_jump := func(_v: float = 0.0) -> void:
		if not is_instance_valid(jump) or not is_instance_valid(map_view) or not is_instance_valid(map_scroll):
			return
		var y := map_view.node_pos(target_stage).y
		var top := float(map_scroll.scroll_vertical)
		var above := y < top + 40.0
		var below := y > top + map_scroll.size.y - 40.0
		jump.visible = above or below
		jump.text = "Go to stage %d %s" % [target_stage + 1, "(up)" if above else "(down)"]
	map_scroll.get_v_scroll_bar().value_changed.connect(update_jump)
	_scroll_map_to(target_stage)
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(jump):  # the player left the map already
		return
	update_jump.call()


## Elite and boss stages that have not been cleared yet, with the chest their first clear gives.
func _map_reward_chests() -> Dictionary:
	var out := {}
	for i in Stages.TOTAL:
		if SaveData.stars(i) == 0:
			var list: Array = Rewards.first_clear_chests(i)
			if not list.is_empty():
				out[i] = str(list[0][0])
	return out


## Scrolls so the given stage is a little below the middle of the map view.
func _scroll_map_to(index: int, animated: bool = false) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(map_scroll) or not is_instance_valid(map_view):
		return
	var target := int(map_view.node_pos(index).y - map_scroll.size.y * 0.58)
	if animated:
		create_tween().tween_property(map_scroll, "scroll_vertical", target, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		map_scroll.scroll_vertical = target


func _on_stage_tapped(index: int) -> void:
	if not SaveData.is_unlocked(index):
		sfx.play("click", 0.6)
		_toast("Clear stage %d first!" % (SaveData.highest_unlocked() + 1))
		return
	sfx.play("click", 1.1)
	_open_popup(index)


## Short message that fades away near the bottom of the screen.
func _toast(text: String, seconds: float = 1.1) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.18, 0.1, 0.06, 0.96), UiKit.GOLD, 3, 16))
	var lbl := _label(text, 19, UiKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER, true, false)
	lbl.custom_minimum_size = Vector2(420, 0)  # a fixed width so the text wraps into sensible lines
	panel.add_child(lbl)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	panel.z_index = 50
	# Sits over the top of the board, so the cannonballs and cards stay visible.
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	panel.position.y = size.y * 0.17
	panel.position.x = (size.x - 440.0) / 2.0
	var tw := create_tween()
	tw.tween_interval(seconds)
	tw.tween_property(panel, "modulate:a", 0.0, 0.5)
	tw.tween_callback(panel.queue_free)


## Pop-up for a stage: picture preview, difficulty, best stars and the Play button.
func _open_popup(index: int) -> void:
	_close_popup()
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layer)
	popup = layer
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_close_popup())
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.parchment_style())
	panel.custom_minimum_size = Vector2(380, 0)
	center.add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	panel.add_child(inner)
	var pic := Stages.picture(index)
	inner.add_child(_label("Stage %d" % (index + 1), 38, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true, false))
	var tag := "BOSS" if Stages.is_boss(index) else ("ELITE" if Stages.is_elite(index) else "")
	if Stages.is_night(index):
		tag = (tag + "   NIGHT") if tag != "" else "NIGHT"
	inner.add_child(_label(String(pic["name"]) + ("   -   " + tag if tag != "" else ""), 22, Color("d62839") if tag == "BOSS" else Color("6b4a2f"), HORIZONTAL_ALIGNMENT_CENTER, true, false))
	var preview := PicturePreview.new()
	preview.custom_minimum_size = Vector2(0, 170)
	preview.set_picture(pic["rows"])
	inner.add_child(preview)
	var cells := 0
	var colors := {}
	for r in pic["rows"]:
		for ch in String(r):
			if ch != ".":
				cells += 1
				colors[ch] = true
	inner.add_child(_label("%d barrels   -   %d colors" % [cells, colors.size()], 18, Color("6b4a2f"), HORIZONTAL_ALIGNMENT_CENTER, false, false))
	var sp := Stages.specials_for(index)
	if not sp.is_empty():
		var row := SpecialsRow.new()
		row.set_counts(sp)
		inner.add_child(row)
	var stars := StarsView.new()
	stars.set_value(SaveData.stars(index), 20.0)
	stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(stars)
	inner.add_child(_label("3 stars: %d turns or fewer   -   2 stars: %d" % [Stages.star3_turns(index), Stages.star2_turns(index)], 16, Color("6b4a2f"), HORIZONTAL_ALIGNMENT_CENTER, true, false))
	inner.add_child(_label("Best: %s" % ("not cleared yet" if SaveData.stars(index) == 0 else "%d star%s" % [SaveData.stars(index), "" if SaveData.stars(index) == 1 else "s"]), 16, Color("8a5a30"), HORIZONTAL_ALIGNMENT_CENTER, false, false))
	if not Stages.unlocks_at(index).is_empty():
		inner.add_child(_label("%d new cards unlock here!" % Stages.unlocks_at(index).size(), 17, Color("d62839"), HORIZONTAL_ALIGNMENT_CENTER, true, false))
	inner.add_child(_button("Play", func() -> void: _start_stage(index)))
	inner.add_child(_button("Close", _close_popup, WOOD))
	panel.pivot_offset = Vector2(190, 260)
	panel.scale = Vector2(0.85, 0.85)
	panel.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.15)


func _close_popup() -> void:
	if popup != null and is_instance_valid(popup):
		popup.queue_free()
	popup = null


# ---------- stage flow ----------

func _start_stage(index: int) -> void:
	_close_popup()
	# The first time you reach a stage that unlocks cards, introduce them before playing.
	if not Stages.unlocks_at(index).is_empty() and not SaveData.intro_seen(index):
		show_unlock(index)
	else:
		_begin_stage(index, Stages.deck_for(index))


## Introduces the cards that join the deck at this stage (stages 11, 21, 31 and 41).
func show_unlock(index: int) -> void:
	stage = index
	var box := _new_screen(10)
	box.add_child(RibbonLabel.new("New cards!", 44))
	var note := _label("Stage %d: these %d cards join your deck from now on." % [index + 1, Stages.unlocks_at(index).size()], 18, UiKit.CREAM)
	box.add_child(note)
	var ids: Array = Stages.unlocks_at(index)
	for r in 2:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		for c in 3:
			var cv := _card_button(ids[r * 3 + c], func() -> void: pass)
			cv.custom_minimum_size = Vector2(0, 180)
			cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(cv)
		box.add_child(row)
	box.add_child(_spacer())
	box.add_child(_button("Let's go!", func() -> void:
		SaveData.mark_intro_seen(index)
		sfx.play("reward")
		_begin_stage(index, Stages.deck_for(index))))
	box.add_child(_button("Back to map", func() -> void: show_map(index), WOOD))


## Result after a stage: stars and stats on a win, retry options on a loss.
func show_stage_result(won: bool) -> void:
	var box := _new_screen()
	box.add_child(_spacer())
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.parchment_style())
	box.add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	panel.add_child(inner)
	var final_stage := stage >= Stages.TOTAL - 1
	var title_text := ("Treasure found!" if final_stage else "Stage cleared!") if won else "Out of cannonballs"
	inner.add_child(_label(title_text, 40, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true, false))
	inner.add_child(_label(Stages.title(stage), 18, Color("8a5a30"), HORIZONTAL_ALIGNMENT_CENTER, false, false))
	if won:
		var earned := battle.star_rating()
		var stars := StarsView.new()
		stars.set_value(earned, 30.0)
		stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		inner.add_child(stars)
		stars.reveal()
		inner.add_child(_label("Cleared in %d turn%s." % [battle.turns, "" if battle.turns == 1 else "s"], 20, Color("6b4a2f"), HORIZONTAL_ALIGNMENT_CENTER, true, false))
		var extra := "New best!" if earned > _prev_best else ("Best so far: %d star%s" % [_prev_best, "" if _prev_best == 1 else "s"])
		inner.add_child(_label(extra, 18, Color("d62839") if earned > _prev_best else Color("8a5a30"), HORIZONTAL_ALIGNMENT_CENTER, true, false))
		inner.add_child(_label("3 stars: %d turns or fewer.   2 stars: %d turns or fewer." % [battle.star3_turns, battle.star2_turns], 15, Color("8a5a30"), HORIZONTAL_ALIGNMENT_CENTER, false, false))
		_add_reward_rows(inner)
	else:
		sfx.play("lose")
		inner.add_child(_label("The barrels survived this time. Use the card preview and try a different plan.", 19, Color("6b4a2f"), HORIZONTAL_ALIGNMENT_CENTER, false, false))
	if won and not _last_rewards.is_empty() and not (_last_rewards["chests"] as Dictionary).is_empty():
		box.add_child(_button("Open your chests", func() -> void: packs.show_treasury(func() -> void: show_map(stage)), Color("2a9d8f")))
	if won and not final_stage:
		box.add_child(_button("Next stage", func() -> void: _start_stage(stage + 1)))
		box.add_child(_button("Replay", func() -> void: _start_stage(stage), WOOD))
	elif won:
		box.add_child(_button("Back to the map", func() -> void: show_map(stage)))
	else:
		box.add_child(_button("Try again", func() -> void: _begin_stage(stage, _stage_deck)))
	box.add_child(_button("Map", func() -> void: show_map(stage), WOOD))
	box.add_child(_spacer())


# ---------- options menu (gameplay) ----------

## Opens the options menu over the battle screen. Ignored while shots are still playing out.
func _open_options() -> void:
	if options_layer != null:
		return
	if not _on_menu and (busy or battle == null):
		return
	sfx.play("click")
	_quit_armed = false
	options_layer = Control.new()
	options_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_layer.add_child(options_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_close_options())
	options_layer.add_child(dim)
	_options_holder = CenterContainer.new()
	_options_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_options_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	options_layer.add_child(_options_holder)
	_options_show("settings" if _on_menu else "main")


func _close_options() -> void:
	if options_layer != null and is_instance_valid(options_layer):
		options_layer.queue_free()
	options_layer = null
	_options_holder = null
	_quit_armed = false


## Rebuilds the panel for the given view: "main" or "howto".
func _options_show(view: String) -> void:
	if _options_holder == null:
		return
	for c in _options_holder.get_children():
		c.queue_free()
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.parchment_style())
	panel.custom_minimum_size = Vector2(400, 0)
	_options_holder.add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	panel.add_child(inner)
	if view == "howto":
		inner.add_child(_label("How to play", 36, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true, false))
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(0, 470)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER  # drag to scroll; no bar eating width
		inner.add_child(scroll)
		var rows := VBoxContainer.new()
		rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rows.add_theme_constant_override("separation", 12)
		scroll.add_child(rows)
		_add_howto_rows(rows)
		inner.add_child(_button("Back", func() -> void: _options_show("main"), WOOD))
		return
	if view == "settings":
		_build_settings(inner)
		return
	inner.add_child(_label("Paused", 40, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true, false))
	inner.add_child(_label("Practice" if tutorial else Stages.title(stage), 17, Color("8a5a30"), HORIZONTAL_ALIGNMENT_CENTER, false, false))
	inner.add_child(_button("Resume", _close_options))
	var sound := _button("Sound: Off" if Sfx.muted else "Sound: On", func() -> void: pass, Color("2a9d8f"))
	sound.pressed.connect(func() -> void:
		_toggle_mute()
		sound.text = "Sound: Off" if Sfx.muted else "Sound: On")
	inner.add_child(sound)
	var music_btn := _button("Music: Off" if not Music.enabled else "Music: On", func() -> void: pass, Color("2a9d8f"))
	music_btn.pressed.connect(func() -> void:
		Music.enabled = not Music.enabled
		music.refresh()
		music_btn.text = "Music: On" if Music.enabled else "Music: Off")
	inner.add_child(music_btn)
	inner.add_child(_button("How to play", func() -> void: _options_show("howto"), Color("3a6ea5")))
	inner.add_child(_button("Restart " + ("practice" if tutorial else "stage"), _options_restart, WOOD))
	var quit := _button("Quit to map" if not tutorial else "Quit to menu", func() -> void: pass, WOOD)
	quit.pressed.connect(func() -> void:
		if not _quit_armed:
			_quit_armed = true
			quit.text = "Tap again to quit (progress is lost)"
			quit.add_theme_font_size_override("font_size", 19)
			_set_button_color(quit, Color("d62839"))
		else:
			_options_quit())
	inner.add_child(quit)


func _options_restart() -> void:
	_close_options()
	if tutorial:
		start_tutorial()
	else:
		_begin_stage(stage, _stage_deck)


func _options_quit() -> void:
	var was_tutorial := tutorial
	_close_options()
	if was_tutorial:
		show_menu()
	else:
		show_map(stage)


# ---------- first-time explanation of special barrels ----------

## What each special barrel did, in the words shown in the pop-up. {amount} is filled in at runtime.
const SPECIAL_INTRO: Dictionary = {
	"bomb": ["Bomb Barrel!", "It exploded and smashed the barrels around it. Smash bombs next to other barrels to clear lots at once. Bombs can set off other bombs!"],
	"ammo": ["Supply Crate!", "It gave you a free cannonball with %d hits, ready to fire next turn. Crates are the best way to save cannonballs."],
	"iron": ["Iron Barrel!", "It only cracked. Iron barrels take two hits to break, so plan an extra hit for each one."],
	"curse": ["Cursed Skull!", "It cursed your next cannonball: it lost %d hits. Try to smash skulls with a cannonball you can spare."],
}


## Pop-up shown the first time a special barrel effect happens. Pauses the game until the player
## taps the button. Await it: it returns when the pop-up closes.
func _show_special_intro(kind: String) -> void:
	SaveData.mark_special_seen(kind)
	sfx.play("sparkle")
	var good := SpecialArt.is_good(kind)
	var amount := Battle.AMMO_CRATE_HITS if kind == "ammo" else Battle.CURSE_HITS
	var info: Array = SPECIAL_INTRO[kind]
	var body: String = String(info[1]) % amount if String(info[1]).contains("%d") else String(info[1])
	_intro_open = Control.new()
	_intro_open.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_layer.add_child(_intro_open)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_intro_open.add_child(dim)
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_open.add_child(holder)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.parchment_style())
	panel.custom_minimum_size = Vector2(390, 0)
	holder.add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	panel.add_child(inner)
	# Buff / debuff tag.
	var tag := _label("BUFF  -  helps you" if good else "DEBUFF  -  hurts you", 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true, false)
	tag.add_theme_stylebox_override("normal", UiKit.panel_style(Color("2fa84f") if good else Color("c4284d"), Color("1d6b34") if good else Color("7a1230"), 3, 14))
	tag.custom_minimum_size = Vector2(300, 0)
	tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(tag)
	inner.add_child(_label(String(info[0]), 36, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true, false))
	var icon := SpecialIntroIcon.new(kind)
	inner.add_child(icon)
	inner.add_child(_label(body, 18, Color("5a3a22"), HORIZONTAL_ALIGNMENT_CENTER, false, false))
	var ok := _button("Got it!", func() -> void: _intro_closed.emit(), Color("2a9d8f") if good else Color("ef476f"))
	inner.add_child(ok)
	panel.pivot_offset = Vector2(195, 230)
	panel.scale = Vector2(0.8, 0.8)
	panel.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.15)
	await _intro_closed
	_intro_open.queue_free()
	_intro_open = null


## Settings panel for the main menu: sound, music, how to play and (after a second tap) reset progress.
func _build_settings(inner: VBoxContainer) -> void:
	inner.add_child(_label("Settings", 40, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true, false))
	var sound := _button("Sound: Off" if Sfx.muted else "Sound: On", func() -> void: pass, Color("2a9d8f"))
	sound.pressed.connect(func() -> void:
		_toggle_mute()
		sound.text = "Sound: Off" if Sfx.muted else "Sound: On")
	inner.add_child(sound)
	var music_btn := _button("Music: On" if Music.enabled else "Music: Off", func() -> void: pass, Color("2a9d8f"))
	music_btn.pressed.connect(func() -> void:
		Music.enabled = not Music.enabled
		music.refresh()
		music_btn.text = "Music: On" if Music.enabled else "Music: Off")
	inner.add_child(music_btn)
	inner.add_child(_button("How to play", func() -> void:
		_close_options()
		show_howto(), Color("3a6ea5")))
	var dbg := _button("Debug: all stages open" if SaveData.debug_unlock else "Debug: off", func() -> void: pass, Color("8e54d9") if SaveData.debug_unlock else Color("5a4a6a"))
	dbg.pressed.connect(func() -> void:
		SaveData.set_debug_unlock(not SaveData.debug_unlock)
		dbg.text = "Debug: all stages open" if SaveData.debug_unlock else "Debug: off"
		_set_button_color(dbg, Color("8e54d9") if SaveData.debug_unlock else Color("5a4a6a")))
	inner.add_child(dbg)
	var reset := _button("Reset progress", func() -> void: pass, WOOD)
	var armed := [false]
	reset.pressed.connect(func() -> void:
		if not armed[0]:
			armed[0] = true
			reset.text = "Tap again: erase all stars"
			reset.add_theme_font_size_override("font_size", 20)
			_set_button_color(reset, Color("d62839"))
		else:
			SaveData.reset()
			_close_options()
			show_menu())
	inner.add_child(reset)
	inner.add_child(_button("Close", _close_options))


## Doubloons and chests the stage just paid, as rows on the results panel.
func _add_reward_rows(inner: VBoxContainer) -> void:
	if _last_rewards.is_empty():
		return
	var gold := int(_last_rewards["doubloons"])
	if gold > 0:
		inner.add_child(_label("+%d Doubloons" % gold, 22, Color("a8651a"), HORIZONTAL_ALIGNMENT_CENTER, true, false))
	var chests: Dictionary = _last_rewards["chests"]
	if chests.is_empty():
		return
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	for id in chests:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		cell.custom_minimum_size = Vector2(150, 0)
		var icon := ChestView.new(str(id), false)
		icon.custom_minimum_size = Vector2(80, 64)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_child(icon)
		cell.add_child(_label("%s x%d" % [PackConfig.chest(str(id))["name"], int(chests[id])], 14, Color("6b4a2f"), HORIZONTAL_ALIGNMENT_CENTER, true, false))
		row.add_child(cell)
	inner.add_child(row)


# ---------- daily gift ----------

## Claims today's gift: a random rare, epic or (rarely) legendary card that joins the next stage's deck.
func _claim_daily_gift() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var id := Stages.roll_gift(rng)
	SaveData.claim_daily(id)
	sfx.play("sparkle")
	await _show_gift_popup(id)
	show_menu()


func _show_gift_popup(id: String) -> void:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_layer.add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(holder)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.parchment_style())
	panel.custom_minimum_size = Vector2(380, 0)
	holder.add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	panel.add_child(inner)
	inner.add_child(_label("Daily gift!", 40, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true, false))
	var card := _card_button(id, func() -> void: pass)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size = Vector2(170, 200)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(card)
	inner.add_child(_label("This card joins your deck for the next stage you play. Come back tomorrow for another gift.", 17, Color("6b4a2f"), HORIZONTAL_ALIGNMENT_CENTER, false, false))
	var ok := _button("Thanks!", func() -> void: _intro_closed.emit(), Color("2a9d8f"))
	inner.add_child(ok)
	panel.pivot_offset = Vector2(190, 260)
	panel.scale = Vector2(0.8, 0.8)
	panel.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.15)
	await _intro_closed
	layer.queue_free()
