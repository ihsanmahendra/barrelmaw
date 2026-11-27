class_name FeatureArt
extends RefCounted
## PLACEHOLDER drawings for the features after Rebalance v1. The Art session owns the final look and can
## replace any function body; the signatures are what the screens call.

const OUT := Color("3a1f12")


## Emblem of a boss rule: "ghost", "armor" or "curse".
static func draw_boss_emblem(c: CanvasItem, center: Vector2, size: float, rule: String) -> void:
	var r := size / 2.0
	match rule:
		"ghost":
			for k in 3:
				PirateArt.draw_barrel(c, center + Vector2((k - 1) * size * 0.62, 0), size * 0.55, size * 0.7, Color("8ff0e4"))
		"armor":
			for k in 3:
				var at := center + Vector2((k - 1) * size * 0.62, 0)
				PirateArt.draw_barrel(c, at, size * 0.55, size * 0.7, Color("8d93a5"))
				SpecialArt.draw_special(c, at, size * 0.58, "iron", 2, 0.0)
		_:
			for k in 3:
				var at := center + Vector2((k - 1) * size * 0.62, 0)
				c.draw_circle(at, r * 0.55, Color("4a2b6b"), true, -1.0, true)
				SpecialArt.draw_special(c, at, size * 0.62, "curse", 2, 0.0)


## The Kraken's arm sweeping from `from` towards `to`; t runs from 0 to 1.
static func draw_tentacle(c: CanvasItem, from: Vector2, to: Vector2, t: float) -> void:
	var reach := clampf(t * 1.4, 0.0, 1.0)
	var fade := clampf((1.0 - t) * 3.0, 0.0, 1.0)
	var dir := to - from
	var side := Vector2(-dir.y, dir.x).normalized()
	var prev := from
	for i in range(1, 25):
		var k := float(i) / 24.0 * reach
		var p := from + dir * k + side * sin(k * 7.0 + t * 8.0) * 22.0 * (1.0 - k * 0.5)
		var w := lerpf(30.0, 7.0, float(i) / 24.0)
		c.draw_line(prev, p, Color(0.15, 0.19, 0.31, 0.95 * fade), w, true)
		if i % 3 == 0:
			c.draw_circle(p + side * w * 0.2, w * 0.18, Color(0.79, 0.83, 0.91, fade), true, -1.0, true)
		prev = p


## A skull dropping onto a barrel at `center`; t runs from 0 to 1.
static func draw_falling_skull(c: CanvasItem, center: Vector2, size: float, t: float) -> void:
	var fall := clampf(t * 1.6, 0.0, 1.0)
	var at := center + Vector2(0, -(1.0 - fall * fall) * size * 5.0)
	var fade := clampf((1.0 - t) * 3.0, 0.0, 1.0)
	c.draw_circle(at, size * 0.52, Color(0.2, 0.11, 0.3, 0.85 * fade), true, -1.0, true)
	c.draw_circle(at + Vector2(0, -size * 0.06), size * 0.3, Color(0.96, 0.93, 1.0, fade), true, -1.0, true)
	c.draw_rect(Rect2(at + Vector2(-size * 0.17, size * 0.12), Vector2(size * 0.34, size * 0.2)), Color(0.96, 0.93, 1.0, fade))
	for dx in [-0.12, 0.12]:
		c.draw_circle(at + Vector2(size * dx, -size * 0.06), size * 0.08, Color(0.2, 0.11, 0.3, fade), true, -1.0, true)


## Menu button picture for the Daily Haul: a stack of coins.
static func draw_haul_icon(c: CanvasItem, center: Vector2, size: float) -> void:
	for k in 3:
		var at := center + Vector2(0, size * (0.26 - 0.22 * k))
		var oval := PackedVector2Array()
		for i in 20:
			var a := TAU * i / 20.0
			oval.append(at + Vector2(cos(a) * size * 0.45, sin(a) * size * 0.18))
		c.draw_colored_polygon(oval, UiKit.GOLD if k == 2 else Color("e0a020"))
		oval.append(oval[0])
		c.draw_polyline(oval, OUT, 2.0, true)


## Menu button picture for the Captain's Log: an open book.
static func draw_log_icon(c: CanvasItem, center: Vector2, size: float) -> void:
	for side in [-1.0, 1.0]:
		var page := PackedVector2Array([center + Vector2(0, -size * 0.26), center + Vector2(side * size * 0.48, -size * 0.36),
			center + Vector2(side * size * 0.48, size * 0.26), center + Vector2(0, size * 0.36)])
		c.draw_colored_polygon(page, Color("f6ead0"))
		page.append(page[0])
		c.draw_polyline(page, OUT, 2.0, true)
		for k in 3:
			var y := -size * 0.14 + k * size * 0.13
			c.draw_line(center + Vector2(side * size * 0.1, y), center + Vector2(side * size * 0.36, y - size * 0.05), Color("8a5a30"), 1.5, true)


## A button picture on the left side of a button, drawn with one of the icon functions above.
static func add_icon(button: Button, paint: Callable, size: float = 34.0) -> void:
	var icon := Control.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.draw.connect(func() -> void: paint.call(icon, Vector2(size * 0.5 + 14.0, icon.size.y / 2.0 - 2.0), size))
	button.add_child(icon)
