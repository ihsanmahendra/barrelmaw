class_name ResultArt
extends Control
## The scene above the stage result panel, composed from the game's own pieces. A win shows the grinning
## pirate beside an open chest with doubloons raining down; a loss shows him next to the barrels that
## survived, with the cannon still smoking. Scales to whatever height the screen can spare and draws
## nothing when there is too little.

const MIN_HEIGHT: float = 96.0
const OUT := Color("3a1f12")
const COIN := Color("ffc93c")

var won: bool = true
var _time: float = 0.0
var _since: float = 0.0


func _init(p_won: bool = true) -> void:
	won = p_won
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_stretch_ratio = 3.0


func _process(delta: float) -> void:
	_time += delta
	_since += delta
	if _since >= 1.0 / 30.0:  # smooth enough, and easier on a phone
		_since = 0.0
		queue_redraw()


func _draw() -> void:
	if size.y < MIN_HEIGHT:
		return
	var h := minf(size.y - 12.0, 290.0)
	var s := h / 124.0
	var pirate_w := h * PirateArt.PIRATE_ASPECT
	var ground := size.y - 18.0
	_deck(ground, h)
	var feet := Vector2(size.x / 2.0 - pirate_w * 0.3, ground)
	if won:
		_win(feet, s, h, pirate_w, ground)
	else:
		_loss(feet, s, h, pirate_w, ground)


func _win(feet: Vector2, s: float, h: float, pirate_w: float, ground: float) -> void:
	# Doubloons raining behind the pirate.
	for i in 16:
		var phase := fposmod(_time * (0.22 + 0.05 * float(i % 3)) + float(i) * 0.137, 1.0)
		var x := size.x * fposmod(0.07 + float(i) * 0.618, 1.0)
		var fade := clampf(phase * 6.0, 0.0, 1.0) * clampf((1.0 - phase) * 4.0, 0.0, 1.0)
		_coin(Vector2(x, lerpf(-10.0, ground - 10.0, phase)), 6.0 + float(i % 3) * 1.5, absf(cos(_time * 3.0 + float(i))), fade)
	var side := h * 0.42
	var chest_x := maxf(side * 0.7, size.x / 2.0 - pirate_w * 0.5 - side * 0.34)
	ChestArt.draw(self, Vector2(chest_x, ground - side * 0.45), side, "gilded", 1.0, _time)
	_pile(Vector2(minf(size.x - h * 0.22, size.x / 2.0 + pirate_w * 0.68), ground - 4.0), h * 0.045)
	PirateArt.draw_pirate(self, feet, s, _time, 0.0, Transform2D.IDENTITY, false, true)
	for i in 5:
		var k := 0.5 + 0.5 * sin(_time * 3.0 + float(i) * 1.9)
		var at := Vector2(size.x * (0.12 + 0.19 * float(i)), h * (0.12 + 0.17 * float((i * 2) % 3)))
		_sparkle(at, 4.0 + 7.0 * k, Color(1.0, 0.92, 0.55, 0.4 + 0.6 * k))


func _loss(feet: Vector2, s: float, h: float, pirate_w: float, ground: float) -> void:
	# The barrels that got away, stacked and untouched.
	var bw := h * 0.19
	var bh := bw / PirateArt.BARREL_ASPECT
	var bx := maxf(bw * 1.25, size.x / 2.0 - pirate_w * 0.5 - bw * 0.7)
	var bob := sin(_time * 2.0) * 1.5
	PirateArt.draw_barrel(self, Vector2(bx - bw * 0.52, ground - bh * 0.5), bw, bh, Color("4cc9f0"))
	PirateArt.draw_barrel(self, Vector2(bx + bw * 0.52, ground - bh * 0.5), bw, bh, Color("ef476f"))
	PirateArt.draw_barrel(self, Vector2(bx, ground - bh * 1.38 + bob), bw, bh, Color("ffd166"))
	PirateArt.draw_pirate(self, feet, s, _time * 0.5, 0.0)
	var mouth := PirateArt.muzzle(feet, s)
	for i in 6:  # the last of the smoke curling up from an empty cannon
		var phase := fposmod(_time * 0.3 + float(i) / 6.0, 1.0)
		var at := mouth + Vector2(sin(phase * 5.0 + float(i)) * h * 0.03 + phase * h * 0.06, -phase * h * 0.34)
		draw_circle(at, h * (0.022 + 0.045 * phase), Color(0.86, 0.87, 0.9, 0.75 * (1.0 - phase)), true, -1.0, true)


## A wooden deck under the scene (the button plank, tinted), so nobody floats in the sky.
func _deck(ground: float, h: float) -> void:
	var rect := Rect2(Vector2(2.0, ground - h * 0.035), Vector2(size.x - 4.0, maxf(24.0, h * 0.1)))
	var style := UiKit.plank_style(Color("8a5a30"))
	draw_style_box(style, rect)


func _coin(at: Vector2, r: float, turn: float, alpha: float) -> void:
	draw_set_transform(at, 0.0, Vector2(maxf(0.2, turn), 1.0))
	draw_circle(Vector2.ZERO, r + 1.5, Color(OUT, alpha), true, -1.0, true)
	draw_circle(Vector2.ZERO, r, Color(COIN, alpha), true, -1.0, true)
	draw_circle(Vector2(-r * 0.15, -r * 0.2), r * 0.55, Color(1.0, 0.9, 0.5, alpha), true, -1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A little heap of coins lying on the sand.
func _pile(base: Vector2, r: float) -> void:
	for row in 4:
		var n := 5 - row
		for i in n:
			var at := base + Vector2((float(i) - float(n - 1) / 2.0) * r * 1.7, -float(row) * r * 0.85)
			draw_set_transform(at, 0.0, Vector2(1.0, 0.62))
			draw_circle(Vector2.ZERO, r + 1.6, OUT, true, -1.0, true)
			draw_circle(Vector2.ZERO, r, COIN.darkened(0.12), true, -1.0, true)
			draw_circle(Vector2(-r * 0.12, -r * 0.2), r * 0.62, COIN.lightened(0.25), true, -1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _sparkle(at: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var rr := r if i % 2 == 0 else r * 0.25
		pts.append(at + Vector2.from_angle(PI / 4.0 * float(i)) * rr)
	draw_colored_polygon(pts, col)
