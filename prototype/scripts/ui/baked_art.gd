class_name BakedArt
extends RefCounted
## Art drawn in code costs one draw call for nearly every shape: a chest is about 200, a card icon 35, and a
## phone has to issue them again every frame. Here a piece that does not move is painted once into a texture
## at screen resolution and drawn from that afterwards, which is one draw call.
##
## Painting happens in a viewport, which leaves colors multiplied by their alpha; a second viewport divides
## them back, so the texture draws like any picture and soft edges get no dark fringe.

## Turn off to draw everything directly (the performance test compares the two).
static var enabled: bool = true

static var _cache: Dictionary = {}  # key -> {"view": SubViewport, "frame": int}
static var _screen_scale: float = 0.0

const UNPREMULTIPLY: String = """shader_type canvas_item;
render_mode blend_disabled;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
}"""


## Draws the art on c with its anchor at `anchor`. area is the box around the art relative to the anchor, and
## paint is func(item: CanvasItem, anchor: Vector2) that draws it. paint must give the same picture every time
## for one key. zoom is any extra scale set with c.draw_set_transform. Until the texture is ready (the first
## frames, or where nothing renders) the art is painted directly.
static func draw(c: CanvasItem, key: String, anchor: Vector2, area: Rect2, paint: Callable, zoom: float = 1.0) -> void:
	var tex := _texture(c, key, area, paint, zoom)
	if tex == null:
		paint.call(c, anchor)
	else:
		c.draw_texture_rect(tex, Rect2(anchor + area.position, area.size), false)


## The same for art that comes in many colors: paint is func(item, anchor, color). One texture is painted in
## white and tinted when drawn.
static func draw_tinted(c: CanvasItem, key: String, anchor: Vector2, area: Rect2, paint: Callable, tint: Color) -> void:
	var tex := _texture(c, key, area, func(item: CanvasItem, at: Vector2) -> void: paint.call(item, at, Color.WHITE), 1.0)
	if tex == null:
		paint.call(c, anchor, tint)
	else:
		c.draw_texture_rect(tex, Rect2(anchor + area.position, area.size), false, tint)


static func _texture(c: CanvasItem, key: String, area: Rect2, paint: Callable, zoom: float) -> Texture2D:
	if not enabled or not c.is_inside_tree() or DisplayServer.get_name() == "headless":
		return null
	var screen := c.get_viewport().get_final_transform().get_scale().x
	if not is_equal_approx(screen, _screen_scale):  # the window changed size: paint again at the new resolution
		clear()
		_screen_scale = screen
	var px := snappedf(screen * c.get_global_transform().get_scale().x * zoom, 0.05)
	if px <= 0.0:
		return null
	var full_key := "%s@%.2f" % [key, px]
	var entry: Dictionary = _cache.get(full_key, {})
	if entry.is_empty():
		entry = {"view": _bake(c.get_tree(), area, px, paint), "frame": Engine.get_frames_drawn()}
		_cache[full_key] = entry
	var view: SubViewport = entry["view"]
	if view.is_inside_tree() and Engine.get_frames_drawn() >= int(entry["frame"]) + 2:
		return view.get_texture()
	var again := c.queue_redraw
	if not c.get_tree().process_frame.is_connected(again):
		c.get_tree().process_frame.connect(again, CONNECT_ONE_SHOT)
	return null


static func _bake(tree: SceneTree, area: Rect2, px: float, paint: Callable) -> SubViewport:
	var pixels := Vector2i((area.size * px).ceil())
	var out := _viewport(pixels)
	var painted := _viewport(pixels)
	out.add_child(painted)  # a child viewport renders before its parent
	var painter := Node2D.new()
	painter.scale = Vector2(pixels) / area.size  # the node is scaled, so paint may use draw_set_transform
	painter.draw.connect(func() -> void: paint.call(painter, -area.position))
	painted.add_child(painter)
	var resolve := TextureRect.new()
	resolve.texture = painted.get_texture()
	resolve.size = Vector2(pixels)
	var shader := Shader.new()
	shader.code = UNPREMULTIPLY
	var material := ShaderMaterial.new()
	material.shader = shader
	resolve.material = material
	out.add_child(resolve)
	tree.root.add_child.call_deferred(out)  # usually called while drawing, when nodes cannot be added
	return out


static func _viewport(pixels: Vector2i) -> SubViewport:
	var v := SubViewport.new()
	v.size = pixels
	v.transparent_bg = true
	v.disable_3d = true
	v.gui_disable_input = true
	v.render_target_update_mode = SubViewport.UPDATE_ONCE
	return v


## Forgets every baked texture.
static func clear() -> void:
	for entry in _cache.values():
		var view: SubViewport = entry["view"]
		if is_instance_valid(view):
			view.queue_free()
	_cache.clear()
