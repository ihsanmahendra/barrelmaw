class_name MapView
extends Control
## Treasure map of the 20 stages, drawn in code. Stage 1 is at the bottom (the starting beach)
## and stage 20 at the top. Put it inside a ScrollContainer. Emits stage_tapped on a tap.

signal stage_tapped(index: int)

const GAP: float = 168.0
const TOP_PAD: float = 250.0
const BOTTOM_PAD: float = 270.0
const NIGHT_GAP: float = 190.0  # extra space between stage 50 and 51 for the "Night Seas" ribbon

## Stage index to chest id: elite and boss stages whose first-clear chest is still waiting. Set by the screen.
var reward_chests: Dictionary = {}
var _press: Vector2 = Vector2.ZERO
var _view_top: float = 0.0  # visible part of the map (set from the parent scroller each frame)
var _view_bottom: float = 1000.0
var _last_scroll: int = -1
var _since_redraw: float = 0.0

const CULL_MARGIN: float = 260.0
const REDRAW_INTERVAL: float = 1.0 / 30.0  # the map animates gently, 30 fps is plenty
var _sb := StyleBoxFlat.new()


func _ready() -> void:
	custom_minimum_size = Vector2(0, TOP_PAD + BOTTOM_PAD + GAP * (Stages.TOTAL - 1) + NIGHT_GAP)
	mouse_filter = Control.MOUSE_FILTER_PASS  # taps are handled here, drags must still reach the ScrollContainer


func _process(delta: float) -> void:
	_since_redraw += delta
	var sc := get_parent() as ScrollContainer
	var scrolled := false
	if sc != null:
		scrolled = sc.scroll_vertical != _last_scroll
		_last_scroll = sc.scroll_vertical
		_view_top = float(sc.scroll_vertical)
		_view_bottom = _view_top + sc.size.y
	if scrolled or _since_redraw >= REDRAW_INTERVAL:
		_since_redraw = 0.0
		queue_redraw()


## True when something at map height y is on screen (with a margin so nothing pops in at the edges).
func _visible(y: float, margin: float = CULL_MARGIN) -> bool:
	return y > _view_top - margin and y < _view_bottom + margin


## Center of a stage node in this control's pixels.
func node_pos(i: int) -> Vector2:
	var y := size.y - BOTTOM_PAD - float(i) * GAP - (NIGHT_GAP if i >= Stages.NIGHT_START else 0.0)
	var x := size.x * 0.5 + sin(float(i) * 0.9 + 0.5) * size.x * 0.26
	return Vector2(x, y)


## y where the day sea ends and the night sea begins (between stage 50 and stage 51).
func _boundary_y() -> float:
	return (node_pos(Stages.NIGHT_START - 1).y + node_pos(Stages.NIGHT_START).y) / 2.0


func _radius(i: int) -> float:
	return 40.0 if Stages.is_boss(i) else (34.0 if Stages.is_elite(i) else 29.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press = event.position
		elif event.position.distance_to(_press) < 14.0:
			_tap(event.position)


func _tap(p: Vector2) -> void:
	var best := -1
	var best_d := 1e9
	for i in Stages.TOTAL:
		var d := p.distance_to(node_pos(i))
		if d < _radius(i) + 14.0 and d < best_d:
			best_d = d
			best = i
	if best >= 0:
		stage_tapped.emit(best)


func _draw() -> void:
	var t := float(Time.get_ticks_msec()) / 1000.0
	_draw_sea(t)
	_draw_decor(t)
	_draw_start_beach(t)
	_draw_compass()
	for k in Stages.TOTAL:  # far islands (top of the map) first so near ones overlap them
		_draw_island(Stages.TOTAL - 1 - k, t)
	_draw_path()
	var highest := SaveData.highest_unlocked()
	for i in Stages.TOTAL:
		_draw_node(i, highest, t)


# ---------- scenery ----------

func _strip(y0: float, y1: float, top: Color, bottom: Color) -> void:
	if y1 < _view_top - 40.0 or y0 > _view_bottom + 40.0:
		return
	draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(size.x, y0), Vector2(size.x, y1), Vector2(0, y1)]),
		PackedColorArray([top, top, bottom, bottom]))


func _draw_sea(t: float) -> void:
	# Day sea from the start up to stage 50, a dusk band, then the dark night sea up to the end.
	var yb := _boundary_y()
	var band := 260.0
	_strip(yb + band * 0.5, size.y, Color("2278a0"), Color("3ec4d8"))
	_strip(yb - band * 0.5, yb + band * 0.5 + 1.0, Color("0f2a58"), Color("2278a0"))
	_strip(0.0, yb - band * 0.5 + 1.0, Color("050b22"), Color("0f2a58"))
	if _visible(yb, 300.0):
		_night_banner(yb)
	var first := maxf(0.0, floorf((_view_top - 80.0) / 64.0)) * 64.0 + 40.0
	var y := first
	var row := int(first / 64.0)
	while y < minf(size.y, _view_bottom + 80.0):
		var pts := PackedVector2Array()
		var x := 0.0
		while x <= size.x + 12.0:
			pts.append(Vector2(x, y + sin(x * 0.035 + t * 1.2 + row * 1.9) * 3.5))
			x += 12.0
		draw_polyline(pts, Color(1, 1, 1, 0.13 if y > yb else 0.07), 2.0)
		y += 64.0
		row += 1
	# Sparkles on the day sea; twinkling stars on the night sea.
	var first_i := maxi(0, int((_view_top - 40.0) / 7.0))
	for i in range(first_i, mini(first_i + 220, 2600)):
		var px := fposmod(float(i) * 97.3, size.x)
		var py := fposmod(float(i) * 211.7, size.y)
		if not _visible(py, 20.0):
			continue
		var a := 0.5 + 0.5 * sin(t * 2.0 + float(i))
		if py > yb:
			draw_line(Vector2(px - 4, py), Vector2(px + 4, py), Color(1, 1, 1, 0.35 * a), 2.0)
		else:
			draw_circle(Vector2(px, py), 1.2 + float(i % 3) * 0.6, Color(1, 1, 0.92, 0.25 + 0.55 * a))
	if _visible(node_pos(Stages.NIGHT_START + 22).y, 200.0):
		var m := Vector2(size.x * 0.16, node_pos(Stages.NIGHT_START + 22).y)
		draw_circle(m, 74.0, Color(1.0, 0.98, 0.85, 0.10))
		draw_circle(m, 54.0, Color(1.0, 0.98, 0.85, 0.18))
		draw_circle(m, 38.0, Color("f6f0d8"))
		draw_circle(m + Vector2(-12, -8), 7.0, Color(0.82, 0.8, 0.7, 0.8))
		draw_circle(m + Vector2(10, 11), 5.0, Color(0.82, 0.8, 0.7, 0.8))


## Reefs, ships and sea creatures on the open water opposite the path (drawing only).
func _draw_decor(t: float) -> void:
	var yb := _boundary_y()
	for k in Stages.TOTAL - 1:
		var mid := (node_pos(k) + node_pos(k + 1)) / 2.0
		if not _visible(mid.y, 140.0):
			continue
		var lean := (mid.x - size.x * 0.5) / (size.x * 0.26)  # which side the path is on, -1 to 1
		if absf(lean) < 0.4 or absf(mid.y - yb) < 190.0 or mid.y > size.y - 430.0:
			continue
		if absf(mid.y - node_pos(Stages.NIGHT_START + 22).y) < 130.0:
			continue  # the moon hangs there
		var at := Vector2(size.x * (0.5 - signf(lean) * 0.32), mid.y + sin(float(k) * 2.3) * 34.0)
		var light := Color(0.52, 0.62, 0.9) if mid.y < yb else Color.WHITE
		MapDecor.draw(self, at, k * 5 + k / 7, t, light)


## "Night seas" ribbon across the map where stage 51 begins.
func _night_banner(yb: float) -> void:
	var tex := UiKit.ui_texture("ribbon")
	var font := UiKit.bold_font()
	var w := minf(size.x - 40.0, 420.0)
	var h := w * (float(tex.get_height()) / float(tex.get_width())) if tex != null else 90.0
	# The red band is the top part of the ribbon picture; put the band (not the picture) on the stage-51 line.
	var band_c := h * RibbonLabel.BAND_CENTER if tex != null else h * 0.5
	var r := Rect2(Vector2((size.x - w) / 2.0, yb - band_c), Vector2(w, h))
	if tex != null:
		draw_texture_rect(tex, r, false)
	var txt := "Night Seas"
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
	var pos := Vector2(size.x / 2.0 - tw / 2.0, yb + 11.0)
	draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, 8, Color(0.35, 0.05, 0.08, 0.95))
	draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, UiKit.CREAM)
	var sub := "Stages 51 - 100"
	var sw := ThemeDB.fallback_font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	draw_string_outline(ThemeDB.fallback_font, Vector2(size.x / 2.0 - sw / 2.0, r.position.y - 6.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 5, Color(0, 0, 0, 0.7))
	draw_string(ThemeDB.fallback_font, Vector2(size.x / 2.0 - sw / 2.0, r.position.y - 6.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("c9d6ff"))


const START_BEACH_PATH: String = "res://assets/art/map_start_beach.png"
static var _start_beach: Texture2D = null
static var _start_beach_checked: bool = false


## The starting beach is cut from the gameplay background (sand, foam, rocks and the two palms).
func _draw_start_beach(t: float) -> void:
	if not _visible(size.y - 200.0, 420.0):
		return
	if not _start_beach_checked:
		_start_beach_checked = true
		_start_beach = load(START_BEACH_PATH) if ResourceLoader.exists(START_BEACH_PATH) else null
	if _start_beach != null:
		var k := size.x / float(_start_beach.get_width())
		var h := float(_start_beach.get_height()) * k
		draw_texture_rect(_start_beach, Rect2(0.0, size.y - h + 50.0, size.x, h), false)
	else:
		_draw_start_beach_fallback(t)
	_draw_start_label()


func _draw_start_beach_fallback(t: float) -> void:
	var top := size.y - 120.0
	var pts := PackedVector2Array()
	var x := 0.0
	while x <= size.x + 10.0:
		pts.append(Vector2(x, top + sin(x * 0.03 + t) * 5.0))
		x += 10.0
	var sand := PackedVector2Array(pts)
	sand.append(Vector2(size.x, size.y))
	sand.append(Vector2(0, size.y))
	draw_colored_polygon(sand, Color("f2d89a"))
	draw_polyline(pts, Color(1, 1, 1, 0.9), 6.0)
	_palm(Vector2(size.x * 0.12, size.y - 20.0), 90.0, 0.3, t)
	_palm(Vector2(size.x * 0.88, size.y - 12.0), 76.0, -0.3, t + 1.0)


func _draw_start_label() -> void:
	var font := UiKit.bold_font()
	draw_string_outline(font, Vector2(size.x / 2.0 - 40.0, size.y - 36.0), "START", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 8, Color(0.3, 0.18, 0.08, 0.9))
	draw_string(font, Vector2(size.x / 2.0 - 40.0, size.y - 36.0), "START", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UiKit.CREAM)


func _draw_compass() -> void:
	if not _visible(70.0, 80.0):
		return
	var c := Vector2(size.x - 62.0, 70.0)
	draw_circle(c, 44.0, Color(0.96, 0.89, 0.7, 0.85))
	draw_arc(c, 44.0, 0.0, TAU, 32, Color("8a5a30"), 4.0)
	for k in 8:
		var a := -PI / 2.0 + k * PI / 4.0
		var rr := 38.0 if k % 2 == 0 else 22.0
		var tip := c + Vector2(cos(a), sin(a)) * rr
		var b1 := c + Vector2(cos(a + 0.35), sin(a + 0.35)) * 9.0
		var b2 := c + Vector2(cos(a - 0.35), sin(a - 0.35)) * 9.0
		draw_colored_polygon(PackedVector2Array([tip, b1, b2]), Color("d62839") if k == 0 else Color("5a3a22"))
	draw_string_outline(UiKit.bold_font(), c + Vector2(-7, -50), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, Color(0.1, 0.06, 0.03, 0.9))
	draw_string(UiKit.bold_font(), c + Vector2(-7, -50), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UiKit.CREAM)


func _blob(center: Vector2, rx: float, ry: float, seed_value: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 28:
		var a := TAU * float(k) / 28.0
		var wob := 1.0 + 0.09 * sin(a * 3.0 + seed_value) + 0.05 * sin(a * 5.0 + seed_value * 2.0)
		pts.append(center + Vector2(cos(a) * rx * wob, sin(a) * ry * wob))
	return pts


# Generated islands (SpriteCook). anchor is where the stage node sits inside each picture, as a
# fraction of its size; the skull island is for bosses, the chest island for elites.
const ISLAND_ANCHORS: Dictionary = {"palm": Vector2(0.5, 0.66), "dock": Vector2(0.45, 0.62), "chest": Vector2(0.5, 0.66), "skull": Vector2(0.5, 0.64)}
static var _islands: Dictionary = {}


static func _island_tex(island_name: String) -> Texture2D:
	if not _islands.has(island_name):
		var path := "res://assets/art/map_island_%s.png" % island_name
		_islands[island_name] = load(path) if ResourceLoader.exists(path) else null
	return _islands[island_name]


func _island_name(i: int) -> String:
	if Stages.is_boss(i):
		return "skull"
	if Stages.is_elite(i):
		return "chest"
	return "palm" if i % 2 == 0 else "dock"


func _draw_island(i: int, t: float) -> void:
	var p := node_pos(i)
	if not _visible(p.y, 330.0):
		return
	var key := _island_name(i)
	var tex := _island_tex(key)
	if tex != null:
		# Islands of one kind differ in size, and every other pair is mirrored.
		var s := Vector2(tex.get_width(), tex.get_height()) * (0.82 if key == "skull" else 0.68 + 0.04 * float((i * 7) % 3))
		var bob := sin(t * 1.3 + float(i)) * 2.0
		var anchor: Vector2 = ISLAND_ANCHORS[key]
		var mirrored := key != "skull" and (i / 2) % 2 == 1
		var pos := p - s * Vector2(1.0 - anchor.x if mirrored else anchor.x, anchor.y) + Vector2(0, bob)
		if Stages.is_night(i):  # a warm glow from the island's own lights, and moonlit colors
			var gp := p + Vector2(0, -s.y * 0.1)
			for gi in 3:
				draw_circle(gp, s.x * (0.62 - 0.14 * gi), Color(1.0, 0.78, 0.4, 0.05 + 0.03 * gi + 0.01 * sin(t * 2.0 + i)))
		var tint := Color(0.7, 0.78, 1.0) if Stages.is_night(i) else Color.WHITE
		if mirrored:  # a negative width flips the picture
			draw_texture_rect(tex, Rect2(pos, Vector2(-s.x, s.y)), false, tint)
		else:
			draw_texture_rect(tex, Rect2(pos, s), false, tint)
		if i == Stages.TOTAL - 1:
			_draw_treasure(p + Vector2(0, -s.y * anchor.y - 18.0))
		return
	_draw_island_fallback(i, t)


## Drawn island used when the generated pictures are missing.
func _draw_island_fallback(i: int, t: float) -> void:
	var p := node_pos(i)
	var big := Stages.is_boss(i)
	var rx := (86.0 if big else 62.0)
	var ry := (60.0 if big else 44.0)
	var pts := _blob(p, rx + 8.0, ry + 8.0, float(i))
	draw_colored_polygon(pts, Color(1, 1, 1, 0.45 + 0.12 * sin(t * 1.5 + i)))  # foam
	draw_colored_polygon(_blob(p, rx, ry, float(i)), Color("e9cf8f"))
	draw_colored_polygon(_blob(p + Vector2(0, -3), rx * 0.78, ry * 0.7, float(i) + 1.0), Color("f5e2aa"))
	var side := -1.0 if i % 2 == 0 else 1.0
	if i % 3 == 0 and not big:
		_palm(p + Vector2(side * (rx * 0.62), ry * 0.2), 58.0, side * 0.3, t + i)
	elif i % 3 == 1:
		draw_circle(p + Vector2(side * rx * 0.7, ry * 0.5), 10.0, Color("8d93a5"))
		draw_circle(p + Vector2(side * rx * 0.7 - 4, ry * 0.5 - 4), 4.0, Color("b9c0d4"))
	if big:
		_palm(p + Vector2(-rx * 0.7, ry * 0.25), 70.0, 0.3, t + i)
		_palm(p + Vector2(rx * 0.72, ry * 0.3), 62.0, -0.3, t + i + 2.0)
	if i == Stages.TOTAL - 1:
		_draw_treasure(p + Vector2(0, -ry - 38.0))


func _draw_treasure(c: Vector2) -> void:
	draw_rect(Rect2(c + Vector2(-26, -4), Vector2(52, 30)), Color("8a5a30"))
	draw_rect(Rect2(c + Vector2(-26, -4), Vector2(52, 30)), Color("3a261a"), false, 3.0)
	draw_rect(Rect2(c + Vector2(-26, 6), Vector2(52, 5)), Color("3a261a"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-26, -4), c + Vector2(-22, -20), c + Vector2(22, -20), c + Vector2(26, -4)]), Color("a8743f"))
	draw_rect(Rect2(c + Vector2(-5, 2), Vector2(10, 12)), UiKit.GOLD)
	for k in 5:
		draw_circle(c + Vector2(-20 + k * 10, -22 - (k % 2) * 3), 5.0, UiKit.GOLD)


func _palm(base: Vector2, h: float, lean: float, t: float) -> void:
	var top := base + Vector2(lean * h * 0.5, -h)
	draw_line(base, top, Color("8a5a30"), 7.0)
	for k in 5:
		var a := -PI / 2.0 + (k - 2) * 0.62 + sin(t * 1.5 + k) * 0.05
		var dir := Vector2(cos(a), sin(a))
		var mid := top + dir * h * 0.36 + Vector2(0, h * 0.03)
		var tip := top + dir * h * 0.72 + Vector2(0, h * 0.34)
		var nrm := Vector2(-dir.y, dir.x) * h * 0.13
		draw_colored_polygon(PackedVector2Array([top, mid + nrm, tip, mid - nrm]), Color("2e9e4a"))
	draw_circle(top + Vector2(-4, 5), 4.5, Color("5a3a22"))


func _draw_ship(c: Vector2, s: float) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(-20, 0) * s, c + Vector2(20, 0) * s, c + Vector2(13, 10) * s, c + Vector2(-13, 10) * s]), Color("6b4423"))
	draw_line(c + Vector2(0, 0), c + Vector2(0, -32) * s, Color("3a261a"), 3.0 * s)
	draw_colored_polygon(PackedVector2Array([c + Vector2(2, -30) * s, c + Vector2(20, -6) * s, c + Vector2(2, -6) * s]), Color("f6ead0"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-2, -26) * s, c + Vector2(-14, -6) * s, c + Vector2(-2, -6) * s]), Color("e8d9b5"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -32) * s, c + Vector2(12, -29) * s, c + Vector2(0, -26) * s]), Color("d62839"))


# ---------- path and nodes ----------

func _draw_path() -> void:
	for i in Stages.TOTAL - 1:
		var p0 := node_pos(maxi(i - 1, 0))
		var p1 := node_pos(i)
		var p2 := node_pos(i + 1)
		var p3 := node_pos(mini(i + 2, Stages.TOTAL - 1))
		if not (_visible(p1.y, 120.0) or _visible(p2.y, 120.0)):
			continue
		var cleared := SaveData.stars(i) > 0
		var pts: Array = []
		for s in 21:
			var u := float(s) / 20.0
			pts.append(_catmull(p0, p1, p2, p3, u))
		var travelled := 0.0
		var next_dot := 8.0
		for s in range(1, pts.size()):
			var a: Vector2 = pts[s - 1]
			var b: Vector2 = pts[s]
			var seg := a.distance_to(b)
			while next_dot <= travelled + seg:
				var f := (next_dot - travelled) / maxf(seg, 0.001)
				var pos := a.lerp(b, f)
				if cleared:
					draw_circle(pos, 6.0, Color("8a5a1a"))
					draw_circle(pos, 4.5, UiKit.GOLD)
				else:
					draw_circle(pos, 4.2, Color(0.35, 0.22, 0.1, 0.55))
					draw_circle(pos, 3.0, Color(1, 0.96, 0.85, 0.8))
				next_dot += 17.0
			travelled += seg


func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, u: float) -> Vector2:
	var u2 := u * u
	var u3 := u2 * u
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u3)


func _draw_node(i: int, highest: int, t: float) -> void:
	var p := node_pos(i)
	if not _visible(p.y, 120.0):
		return
	var r := _radius(i)
	var stars := SaveData.stars(i)
	var cleared := stars > 0
	var current := i == highest and not cleared
	var locked := not SaveData.is_unlocked(i)
	var boss := Stages.is_boss(i)
	var ring := Color("d62839") if boss else (Color("e08a1e") if Stages.is_elite(i) else Color("5a3a22"))
	var fill := Color("f2c14e") if cleared else (Color("ef476f") if current else Color("8d7b6a"))
	if current:
		var pulse := 0.5 + 0.5 * sin(t * 4.0)
		draw_arc(p, r + 8.0 + 5.0 * pulse, 0.0, TAU, 32, Color(1, 0.9, 0.4, 0.9 - 0.5 * pulse), 5.0)
	draw_circle(p + Vector2(0, 5), r + 3.0, Color(0, 0, 0, 0.3))
	draw_circle(p, r + 4.0, ring)
	draw_circle(p, r, fill)
	draw_circle(p + Vector2(-r * 0.25, -r * 0.3), r * 0.38, Color(1, 1, 1, 0.22))
	var font := UiKit.bold_font()
	if locked:
		_lock_icon(p, r * 0.5)
	else:
		var label := str(i + 1)
		var fs := int(r * 0.95)
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := p + Vector2(-tw / 2.0, fs * 0.36)
		draw_string_outline(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(0.25, 0.12, 0.04, 0.95) if cleared else Color(0.35, 0.05, 0.1, 0.9))
		draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	if boss:  # skull badge
		var b := p + Vector2(r * 0.8, -r * 0.8)
		draw_circle(b, 12.0, Color("fbefd0"))
		draw_arc(b, 12.0, 0.0, TAU, 16, Color("3a261a"), 2.5)
		draw_circle(b + Vector2(-4, -1), 2.8, Color("3a261a"))
		draw_circle(b + Vector2(4, -1), 2.8, Color("3a261a"))
		draw_rect(Rect2(b + Vector2(-3, 4), Vector2(6, 4)), Color("3a261a"))
	elif Stages.is_elite(i):
		UiKit.draw_star(self, p + Vector2(r * 0.8, -r * 0.8), 13.0, Color("e08a1e"), Color("5a3a22"))
	if reward_chests.has(i):  # the chest this stage pays the first time
		ChestArt.draw(self, p + Vector2(-r - 18.0, -r * 0.5), 42.0, str(reward_chests[i]), 0.0, t)
	if cleared:
		for k in 3:
			var sc := p + Vector2((k - 1) * 19.0, r + 20.0 - (6.0 if k != 1 else 0.0))
			UiKit.draw_star(self, sc, 9.0, UiKit.GOLD if k < stars else Color(0.2, 0.13, 0.08, 0.7), Color("a8651a") if k < stars else Color(0.5, 0.4, 0.3, 0.8))
	if current:
		_draw_ship(p + Vector2(-r - 30.0 if i % 2 == 0 else r + 30.0, -4.0 + sin(t * 2.2) * 4.0), 0.95)


func _lock_icon(c: Vector2, s: float) -> void:
	_sb.bg_color = Color(1, 1, 1, 0.85)
	_sb.set_corner_radius_all(int(s * 0.3))
	_sb.set_border_width_all(0)
	draw_style_box(_sb, Rect2(c + Vector2(-s * 0.8, -s * 0.1), Vector2(s * 1.6, s * 1.2)))
	draw_arc(c + Vector2(0, -s * 0.1), s * 0.55, PI, TAU, 14, Color(1, 1, 1, 0.85), maxf(3.0, s * 0.22))
	draw_circle(c + Vector2(0, s * 0.5), s * 0.2, Color(0.35, 0.28, 0.22))
