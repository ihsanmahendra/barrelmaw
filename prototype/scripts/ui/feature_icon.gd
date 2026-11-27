class_name FeatureIcon
extends Control
## One FeatureArt icon as a control, filling its size: "haul", "log", a boss rule ("ghost",
## "armor", "curse") or an elite rule key from Stages.ELITE_TEXT.

var kind: String = "haul":
	set(value):
		kind = value
		queue_redraw()


func _init(p_kind: String = "haul", side: float = 40.0) -> void:
	kind = p_kind
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(side, side)
	resized.connect(queue_redraw)


func _draw() -> void:
	var side := minf(size.x, size.y)
	var center := size / 2.0
	if kind == "haul":
		FeatureArt.draw_haul_icon(self, center, side)
	elif kind == "log":
		FeatureArt.draw_log_icon(self, center, side)
	elif FeatureArt.BOSS_COLORS.has(kind):
		FeatureArt.draw_boss_emblem(self, center, side, kind)
	else:
		FeatureArt.draw_elite_icon(self, center, side, kind)
