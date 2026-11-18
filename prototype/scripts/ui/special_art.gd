class_name SpecialArt
extends RefCounted
## Icons for the special barrels, drawn on top of a barrel cell (or on their own in the how-to and
## stage pop-up). All shapes scale with cs, the cell size in pixels.

const NAMES: Dictionary = {
	"bomb": "Bomb barrel",
	"ammo": "Supply crate",
	"iron": "Iron barrel",
	"curse": "Cursed skull",
}
const HELP: Dictionary = {
	"bomb": "Explodes and smashes the barrels around it.",
	"ammo": "Gives you a free cannonball.",
	"iron": "Takes two hits to break.",
	"curse": "Smashing it weakens your next cannonball.",
}
const GOOD: Array = ["bomb", "ammo"]


static func is_good(kind: String) -> bool:
	return GOOD.has(kind)


## Draws one special icon centered at center. hp is the barrel's remaining hit points (iron shows
## cracks at 1). t is time in seconds, used for the flickering fuse and the curse glow.
static func draw_special(c: CanvasItem, center: Vector2, cs: float, kind: String, hp: int, t: float) -> void:
	match kind:
		"bomb":
			_bomb(c, center, cs, t)
		"ammo":
			_crate(c, center, cs, t)
		"iron":
			_iron(c, center, cs, hp)
		"curse":
			_skull(c, center, cs, t)


static func _bomb(c: CanvasItem, p: Vector2, cs: float, t: float) -> void:
	var r := cs * 0.27
	var b := p + Vector2(0.0, cs * 0.06)
	c.draw_circle(b + Vector2(0.0, cs * 0.03), r * 1.08, Color(0, 0, 0, 0.35))
	c.draw_circle(b, r, Color("1f2233"))
	c.draw_circle(b, r * 0.86, Color("34384f"))
	c.draw_circle(b + Vector2(-r * 0.34, -r * 0.36), r * 0.26, Color(1, 1, 1, 0.55))
	# Fuse with a flickering spark.
	var top := b + Vector2(r * 0.25, -r * 0.88)
	var tip := top + Vector2(r * 0.55, -r * 0.55)
	c.draw_line(top, tip, Color("a8743f"), maxf(2.0, cs * 0.06))
	var flick := 0.6 + 0.4 * sin(t * 18.0)
	c.draw_circle(tip, cs * 0.11 * flick + 2.0, Color(1.0, 0.55, 0.15, 0.55))
	c.draw_circle(tip, cs * 0.06 * flick + 1.2, Color(1.0, 0.92, 0.5))


static func _crate(c: CanvasItem, p: Vector2, cs: float, t: float) -> void:
	var r := cs * 0.3
	c.draw_circle(p + Vector2(0.0, cs * 0.04), r * 1.06, Color(0, 0, 0, 0.35))
	c.draw_circle(p, r, Color("8a5a1a"))
	c.draw_circle(p, r * 0.88, Color("ffd166"))
	c.draw_circle(p + Vector2(-r * 0.3, -r * 0.34), r * 0.3, Color(1, 1, 1, 0.5))
	var w := maxf(2.5, cs * 0.075)
	var a := r * 0.52
	c.draw_line(p + Vector2(-a, 0.0), p + Vector2(a, 0.0), Color("7a4a10"), w)
	c.draw_line(p + Vector2(0.0, -a), p + Vector2(0.0, a), Color("7a4a10"), w)
	var tw := 0.5 + 0.5 * sin(t * 5.0)
	c.draw_circle(p + Vector2(r * 0.7, -r * 0.7), cs * 0.045 * (0.6 + tw), Color(1, 1, 1, 0.5 + 0.5 * tw))


static func _iron(c: CanvasItem, p: Vector2, cs: float, hp: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.6, 0.65, 0.74, 0.62)
	sb.set_corner_radius_all(int(cs * 0.18))
	sb.set_border_width_all(maxi(2, int(cs * 0.07)))
	sb.border_color = Color(0.22, 0.25, 0.33, 0.95)
	var half := cs * 0.40
	c.draw_style_box(sb, Rect2(p - Vector2(half, half), Vector2(half, half) * 2.0))
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var rv := p + Vector2(sx * half * 0.68, sy * half * 0.68)
			c.draw_circle(rv, cs * 0.05, Color(0.2, 0.22, 0.3))
			c.draw_circle(rv + Vector2(-cs * 0.012, -cs * 0.012), cs * 0.02, Color(0.85, 0.88, 0.95))
	if hp <= 1:  # already hit once: cracked
		var w := maxf(1.5, cs * 0.05)
		c.draw_polyline(PackedVector2Array([p + Vector2(-half * 0.2, -half), p + Vector2(half * 0.05, -half * 0.35), p + Vector2(-half * 0.25, half * 0.1), p + Vector2(half * 0.15, half)]), Color(0.1, 0.1, 0.14), w)
		c.draw_polyline(PackedVector2Array([p + Vector2(half * 0.05, -half * 0.35), p + Vector2(half * 0.7, -half * 0.1)]), Color(0.1, 0.1, 0.14), w)


static func _skull(c: CanvasItem, p: Vector2, cs: float, t: float) -> void:
	var glow := 0.5 + 0.5 * sin(t * 3.0)
	c.draw_circle(p, cs * (0.34 + 0.03 * glow), Color(0.55, 0.15, 0.85, 0.35 + 0.2 * glow))
	var r := cs * 0.2
	c.draw_circle(p + Vector2(0.0, -cs * 0.02), r, Color("f4efe4"))
	c.draw_rect(Rect2(p + Vector2(-r * 0.55, r * 0.55), Vector2(r * 1.1, r * 0.7)), Color("f4efe4"))
	c.draw_circle(p + Vector2(-r * 0.4, -cs * 0.03), r * 0.3, Color("2a1233"))
	c.draw_circle(p + Vector2(r * 0.4, -cs * 0.03), r * 0.3, Color("2a1233"))
	c.draw_rect(Rect2(p + Vector2(-r * 0.12, r * 0.18), Vector2(r * 0.24, r * 0.22)), Color("2a1233"))
	for k in [-0.3, 0.0, 0.3]:
		c.draw_line(p + Vector2(r * k, r * 0.75), p + Vector2(r * k, r * 1.2), Color("2a1233"), 1.2)
