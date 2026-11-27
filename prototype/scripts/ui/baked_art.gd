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
static var _unpremultiply: ShaderMaterial = null
static var _bake_frame: int = -1
static var _soft: Dictionary = {}  # roundness -> Texture2D

## A ceiling on textures, so that no mistake in a key can eat a phone's memory. Past it, art is drawn directly.
const MAX_TEXTURES: int = 200

const UNPREMULTIPLY: String = """shader_type canvas_item;
render_mode blend_disabled;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
}"""


## Draws the art on c with its anchor at `anchor`. area is the box around the art relative to the anchor, and
## paint is func(item: CanvasItem, anchor: Vector2) that draws it. paint must give the same picture every time
## for one key. zoom is any extra scale set with c.draw_set_transform. A scale on the node itself is left out on
## purpose: cards are tweened as they are dealt, and one texture per animation step crashed phones. Until the texture is ready (the first
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
		c.get_tree().root.propagate_call("queue_redraw")  # whatever showed an old texture paints again
	var px := snappedf(screen * zoom, 0.05)
	if px <= 0.0:
		return null
	var full_key := "%s@%.2f" % [key, px]
	var entry: Dictionary = _cache.get(full_key, {})
	if entry.is_empty():
		if _cache.size() >= MAX_TEXTURES:
			return null
		if _bake_frame == Engine.get_frames_drawn():  # one a frame: several at once is a visible hitch
			_redraw_later(c)
			return null
		_bake_frame = Engine.get_frames_drawn()
		entry = {"view": _bake(c.get_tree(), area, px, paint), "frame": Engine.get_frames_drawn()}
		_cache[full_key] = entry
	var view: SubViewport = entry["view"]
	if view.is_inside_tree() and Engine.get_frames_drawn() >= int(entry["frame"]) + 2:
		return view.get_texture()
	_redraw_later(c)
	return null


static func _redraw_later(c: CanvasItem) -> void:
	var again := c.queue_redraw
	if not c.get_tree().process_frame.is_connected(again):
		c.get_tree().process_frame.connect(again, CONNECT_ONE_SHOT)


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
	resolve.material = _material()
	out.add_child(resolve)
	tree.root.add_child.call_deferred(out)  # usually called while drawing, when nodes cannot be added
	return out


## One shader for every texture: a new one each time is compiled again, a stutter on a phone.
static func _material() -> ShaderMaterial:
	if _unpremultiply == null:
		var shader := Shader.new()
		shader.code = UNPREMULTIPLY
		_unpremultiply = ShaderMaterial.new()
		_unpremultiply.shader = shader
	return _unpremultiply


static func _viewport(pixels: Vector2i) -> SubViewport:
	var v := SubViewport.new()
	v.size = pixels
	v.transparent_bg = true
	v.disable_3d = true
	v.gui_disable_input = true
	v.render_target_update_mode = SubViewport.UPDATE_ONCE
	return v


## A white rounded square (roundness 0.3) or disc (1.0) to tint and stretch. Debris, flashes and smoke drawn
## with one of these share a draw call, where each draw_circle or rounded box costs its own.
static func soft_shape(roundness: float) -> Texture2D:
	if not _soft.has(roundness):
		var n := 64
		var radius := roundness * n / 2.0
		var image := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var qx := maxf(absf(x + 0.5 - n / 2.0) - (n / 2.0 - radius), 0.0)
				var qy := maxf(absf(y + 0.5 - n / 2.0) - (n / 2.0 - radius), 0.0)
				image.set_pixel(x, y, Color(1, 1, 1, clampf(radius - sqrt(qx * qx + qy * qy) + 0.5, 0.0, 1.0)))
		image.generate_mipmaps()
		_soft[roundness] = ImageTexture.create_from_image(image)
	return _soft[roundness]


## Forgets every baked texture.
static func clear() -> void:
	for entry in _cache.values():
		var view: SubViewport = entry["view"]
		if is_instance_valid(view):
			view.queue_free()
	_cache.clear()
