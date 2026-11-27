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


## The icons never move, so each is painted once into a texture (see BakedArt): drawn shape by shape the two
## menu icons alone cost over a hundred draw calls every frame.
func _draw() -> void:
	var side := snappedf(minf(size.x, size.y), 0.5)
	if side <= 0.0:
		return
	var which := kind
	BakedArt.draw(self, "icon:%s:%.1f" % [which, side], size / 2.0, Rect2(-side * 0.6, -side * 0.6, side * 1.2, side * 1.2),
		func(item: CanvasItem, at: Vector2) -> void: paint(item, which, at, side))


static func paint(c: CanvasItem, which: String, center: Vector2, side: float) -> void:
	if which == "haul":
		FeatureArt.draw_haul_icon(c, center, side)
	elif which == "log":
		FeatureArt.draw_log_icon(c, center, side)
	elif FeatureArt.BOSS_COLORS.has(which):
		FeatureArt.draw_boss_emblem(c, center, side, which)
	else:
		FeatureArt.draw_elite_icon(c, center, side, which)
