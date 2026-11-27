class_name HowtoArt
extends Control
## Small illustrations for the how-to steps, drawn with the game's own barrels, cannonballs,
## cards and buttons so players see exactly what they will meet in a stage.

const SIZE := Vector2(112, 82)

var kind: int = 0  # 0 smash barrels, 1 cannonball queue, 2 card preview, 3 fire and stars, 4 specials, 5 chests


func _init(p_kind: int = 0) -> void:
	kind = p_kind
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	# Soft wooden frame behind each picture.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.36, 0.24, 0.15, 0.9)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(3)
	sb.border_color = Color("8a5a30")
	draw_style_box(sb, Rect2(Vector2.ZERO, SIZE))
	match kind:
		0:
			_draw_smash()
		1:
			_draw_queue()
		2:
			_draw_preview()
		4:
			_draw_specials()
		5:
			_draw_chests()
		_:
			_draw_fire()


func _draw_smash() -> void:
	var cols := [Color("ef476f"), Color("4cc9f0"), Color("ffd166")]
	for r in 3:
		for c in 4:
			var center := Vector2(22.0 + c * 25.0, 18.0 + r * 22.0)
			if r == 1 and (c == 1 or c == 2):
				# A smashed barrel: burst of chips.
				for k in 7:
					var a := float(k) * TAU / 7.0 + 0.3
					draw_circle(center + Vector2(cos(a), sin(a)) * 8.0, 2.6, Color("e0a65a") if k % 2 == 0 else cols[(c + r) % 3])
				draw_circle(center, 4.0, Color(1, 1, 1, 0.9))
			else:
				PirateArt.draw_barrel(self, center, 19.0, 22.0, cols[(c + r) % 3])
	PirateArt.draw_cannonball(self, Vector2(21.0, 69.0), 8.0, Color("ef476f"))
	draw_dashed_line(Vector2(30.0, 66.0), Vector2(46.0, 42.0), Color(1, 1, 1, 0.8), 2.0, 5.0)


func _draw_queue() -> void:
	var font := UiKit.bold_font()
	var balls := [[Color("ef476f"), "3", 18.0], [Color("4cc9f0"), "2", 13.0], [Color("ef476f"), "4", 13.0]]
	var x := 26.0
	for i in balls.size():
		var r: float = balls[i][2]
		var center := Vector2(x, 52.0)
		PirateArt.draw_cannonball(self, center, r, balls[i][0], balls[i][1], int(r * 0.95))
		if i == 0:
			var w := font.get_string_size("NEXT", HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			draw_string_outline(font, Vector2(x - w / 2.0, 20.0), "NEXT", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0.1, 0.07, 0.05, 0.8))
			draw_string(font, Vector2(x - w / 2.0, 20.0), "NEXT", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiKit.GOLD)
		x += r + balls[min(i + 1, 2)][2] + 5.0
	# Arrow pointing along the queue: the left one goes first.
	draw_line(Vector2(14.0, 74.0), Vector2(100.0, 74.0), Color(1, 1, 1, 0.6), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(14.0, 74.0), Vector2(21.0, 70.0), Vector2(21.0, 78.0)]), Color(1, 1, 1, 0.6))


func _draw_preview() -> void:
	# Barrels with white outlines (what will be smashed) and a card hovering in front.
	var sbo := StyleBoxFlat.new()
	sbo.bg_color = Color(1, 1, 1, 0.12)
	sbo.set_corner_radius_all(6)
	sbo.set_border_width_all(2)
	sbo.border_color = Color(1, 1, 1, 0.95)
	for c in 5:
		var center := Vector2(16.0 + c * 21.0, 62.0)
		PirateArt.draw_barrel(self, center, 17.0, 20.0, Color("4cc9f0"))
		draw_style_box(sbo, Rect2(center - Vector2(10.0, 11.0), Vector2(20.0, 22.0)))
	var card := Rect2(Vector2(34.0, 6.0), Vector2(50.0, 42.0))
	var cb := StyleBoxFlat.new()
	cb.bg_color = UiKit.PARCHMENT
	cb.set_corner_radius_all(7)
	cb.set_border_width_all(3)
	cb.border_color = Color("2f9fd0")
	cb.shadow_color = Color(0, 0, 0, 0.35)
	cb.shadow_size = 4
	draw_style_box(cb, card)
	var font := UiKit.bold_font()
	PirateArt.draw_cannonball(self, Vector2(52.0, 27.0), 9.0, Color("ef476f"))
	draw_string_outline(font, Vector2(61.0, 36.0), "+3", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0.1, 0.07, 0.05, 0.9))
	draw_string(font, Vector2(61.0, 36.0), "+3", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiKit.GOLD)


func _draw_fire() -> void:
	var font := UiKit.bold_font()
	# FIRE! button.
	var btn := StyleBoxFlat.new()
	btn.bg_color = Color("ef476f")
	btn.set_corner_radius_all(11)
	btn.set_border_width_all(2)
	btn.border_color = Color("8f1d28")
	btn.border_width_bottom = 5
	draw_style_box(btn, Rect2(Vector2(10.0, 8.0), Vector2(98.0, 32.0)))
	var tw := font.get_string_size("FIRE!", HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	draw_string_outline(font, Vector2(59.0 - tw / 2.0, 30.0), "FIRE!", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 4, Color(0.1, 0.06, 0.03, 0.8))
	draw_string(font, Vector2(59.0 - tw / 2.0, 30.0), "FIRE!", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
	# Star counter with the turn limit.
	var chip := StyleBoxFlat.new()
	chip.bg_color = Color(0.2, 0.12, 0.07, 0.92)
	chip.set_corner_radius_all(11)
	chip.set_border_width_all(3)
	chip.border_color = Color("e0a020")
	draw_style_box(chip, Rect2(Vector2(10.0, 48.0), Vector2(98.0, 28.0)))
	for i in 3:
		UiKit.draw_star(self, Vector2(26.0 + i * 17.0, 62.0), 7.0, UiKit.GOLD, Color("a8651a"))
	draw_string_outline(font, Vector2(78.0, 68.0), "4/8", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.7))
	draw_string(font, Vector2(78.0, 68.0), "4/8", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiKit.CREAM)


## A chest, an arrow, and a card that has just gone up a level.
func _draw_chests() -> void:
	var now := float(Time.get_ticks_msec()) / 1000.0
	ChestArt.draw(self, Vector2(34.0, 40.0), 52.0, "iron", 0.55 + 0.45 * sin(now * 2.0) * 0.5, now)
	draw_line(Vector2(60.0, 41.0), Vector2(72.0, 41.0), UiKit.CREAM, 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(70.0, 34.0), Vector2(80.0, 41.0), Vector2(70.0, 48.0)]), UiKit.CREAM)
	var card := Rect2(Vector2(82.0, 14.0), Vector2(24.0, 54.0))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("f3e2bb")
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(2)
	sb.border_color = Color("8d93b5")
	draw_style_box(sb, card)
	draw_circle(card.get_center() + Vector2(0, -8.0), 6.0, Color("ef476f"))
	var c := card.position + Vector2(card.size.x - 1.0, 3.0)
	draw_circle(c, 9.0, Color(0.16, 0.1, 0.05))
	draw_circle(c, 7.5, Color("d7dfec"))
	var f := UiKit.bold_font()
	draw_string(f, c + Vector2(-3.5, 4.5), "2", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.25, 0.14, 0.04))


func _draw_specials() -> void:
	var kinds := ["bomb", "ammo", "iron", "curse"]
	var cols := [Color("ef476f"), Color("ffd166"), Color("4cc9f0"), Color("9b5de5")]
	var now := float(Time.get_ticks_msec()) / 1000.0
	for i in 4:
		var c := Vector2(14.0 + (i % 2) * 42.0 + 14.0, 20.0 + (i / 2) * 40.0)
		PirateArt.draw_barrel(self, c, 30.0, 34.0, cols[i])
		SpecialArt.draw_special(self, c, 34.0, kinds[i], 2, now)
