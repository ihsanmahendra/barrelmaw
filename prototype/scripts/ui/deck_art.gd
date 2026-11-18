class_name DeckArt
extends RefCounted
## Procedural ship-deck drawing: a plank wall with a rail and portholes, a plank floor with
## nails, and optional masts with rope rungs at the screen edges.

const WALL_H: float = 46.0


## Draws the deck inside rect: the wall and rail along the top edge, the floor below it.
static func draw_deck(c: CanvasItem, rect: Rect2, t: float = 0.0) -> void:
	var x0 := rect.position.x
	var w := rect.size.x
	var top := rect.position.y
	# Wall (the ship's side) with vertical plank seams.
	c.draw_rect(Rect2(x0, top, w, WALL_H), Color("5a3a22"))
	var seam := 0.0
	while seam < w:
		c.draw_line(Vector2(x0 + seam, top), Vector2(x0 + seam, top + WALL_H), Color(0.16, 0.09, 0.05, 0.6), 2.0)
		seam += 38.0
	for px in [0.24, 0.62, 0.9]:
		var p := Vector2(x0 + w * px, top + WALL_H * 0.56)
		c.draw_circle(p, 10.0, Color("2a1a10"))
		c.draw_arc(p, 10.0, 0.0, TAU, 18, Color("c9a468"), 3.0)
		c.draw_circle(p + Vector2(-2, -2), 3.0, Color(0.55, 0.75, 0.9, 0.35))
	# Rail along the top of the wall.
	c.draw_rect(Rect2(x0, top - 10.0, w, 16.0), Color("8a5a30"))
	c.draw_rect(Rect2(x0, top - 10.0, w, 4.0), Color("c9a468"))
	c.draw_rect(Rect2(x0, top + 4.0, w, 3.0), Color(0.1, 0.06, 0.03, 0.55))
	# Floor: gradient with perspective plank seams that spread toward the viewer.
	var floor_top := top + WALL_H
	var floor_rect := Rect2(x0, floor_top, w, rect.end.y - floor_top)
	c.draw_polygon(
		PackedVector2Array([floor_rect.position, Vector2(floor_rect.end.x, floor_rect.position.y), floor_rect.end, Vector2(x0, floor_rect.end.y)]),
		PackedColorArray([Color("b07a42"), Color("b07a42"), Color("7a5230"), Color("7a5230")]))
	var y := floor_top
	var row := 0
	var gap := 30.0
	while y < floor_rect.end.y:
		c.draw_line(Vector2(x0, y), Vector2(x0 + w, y), Color(0.16, 0.09, 0.05, 0.55), 2.0)
		c.draw_line(Vector2(x0, y + 2.0), Vector2(x0 + w, y + 2.0), Color(1, 0.9, 0.7, 0.12), 1.5)
		# Staggered butt joints with nails.
		var joint_x := fposmod(float(row) * 137.0, 150.0)
		var jx := x0 + joint_x
		while jx < x0 + w:
			c.draw_line(Vector2(jx, y), Vector2(jx, y + gap), Color(0.16, 0.09, 0.05, 0.5), 2.0)
			c.draw_circle(Vector2(jx + 7.0, y + 8.0), 1.8, Color(0.15, 0.1, 0.07, 0.7))
			c.draw_circle(Vector2(jx - 7.0, y + gap - 8.0), 1.8, Color(0.15, 0.1, 0.07, 0.7))
			jx += 150.0
		y += gap
		gap += 3.0
		row += 1
	# Shadow the wall casts on the floor.
	c.draw_polygon(
		PackedVector2Array([Vector2(x0, floor_top), Vector2(x0 + w, floor_top), Vector2(x0 + w, floor_top + 22.0), Vector2(x0, floor_top + 22.0)]),
		PackedColorArray([Color(0, 0, 0, 0.35), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]))


## Two masts at the left and right edges rising from the rail, with rope rungs and shrouds.
static func draw_masts(c: CanvasItem, width: float, rail_y: float, height: float) -> void:
	var pole := Color("6b4423")
	for side in [0, 1]:
		var x := 6.0 if side == 0 else width - 6.0
		var dir := 1.0 if side == 0 else -1.0
		c.draw_line(Vector2(x, rail_y), Vector2(x, rail_y - height), pole, 15.0)
		c.draw_line(Vector2(x - dir * 4.0, rail_y), Vector2(x - dir * 4.0, rail_y - height), Color("8a5a30"), 4.0)
		# Shrouds from the mast top down to the rail, with rope rungs between them.
		var top := Vector2(x, rail_y - height * 0.72)
		var a := Vector2(x + dir * 46.0, rail_y - 6.0)
		var b := Vector2(x + dir * 18.0, rail_y - 6.0)
		c.draw_line(top, a, Color("d6b98a"), 2.5)
		c.draw_line(top, b, Color("d6b98a"), 2.5)
		for k in 1:
			pass
		var steps := 7
		for i in range(1, steps):
			var f := float(i) / float(steps)
			var p1 := top.lerp(b, f)
			var p2 := top.lerp(a, f)
			c.draw_line(p1, p2, Color("d6b98a"), 2.0)
		c.draw_circle(Vector2(x, rail_y - height), 8.0, Color("4a2f18"))
