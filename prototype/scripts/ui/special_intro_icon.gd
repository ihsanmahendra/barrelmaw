class_name SpecialIntroIcon
extends Control
## Big animated picture of a special barrel for its first-time explanation pop-up: the barrel with
## its icon, sparkles around a buff and a dark glow around a debuff.

var kind: String = "bomb"
var effects: bool = true  # the buff or debuff glow and sparks; off for the elite rule pop-ups


func _init(p_kind: String = "bomb", p_effects: bool = true) -> void:
	kind = p_kind
	effects = p_effects
	custom_minimum_size = Vector2(0, 128)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _ready() -> void:
	set_process(true)


func _draw() -> void:
	var t := float(Time.get_ticks_msec()) / 1000.0
	var c := size / 2.0
	var good := SpecialArt.is_good(kind)
	var glow := Color(0.35, 0.9, 0.45) if good else Color(0.85, 0.25, 0.4)
	for i in 3 if effects else 0:
		var r := 56.0 + i * 12.0 + 4.0 * sin(t * 2.0 + i)
		draw_circle(c, r, Color(glow.r, glow.g, glow.b, 0.10 - i * 0.025))
	var bob := Vector2(0.0, sin(t * 2.4) * 3.0)
	var colors := {"bomb": Color("ef476f"), "ammo": Color("ffd166"), "iron": Color("4cc9f0"), "curse": Color("9b5de5")}
	PirateArt.draw_barrel(self, c + bob, 80.0, 96.0, colors[kind])
	SpecialArt.draw_special(self, c + bob, 96.0, kind, 2, t)
	# Little sparks (buff) or drifting dark wisps (debuff) around the barrel.
	for k in 6 if effects else 0:
		var a := t * (0.9 if good else -0.7) + float(k) * TAU / 6.0
		var p := c + Vector2(cos(a) * 62.0, sin(a) * 50.0)
		if good:
			UiKit.draw_star(self, p, 6.0 + 2.0 * sin(t * 4.0 + k), UiKit.GOLD, Color("a8651a"))
		else:
			draw_circle(p, 5.0 + 1.5 * sin(t * 3.0 + k), Color(0.45, 0.1, 0.5, 0.65))
