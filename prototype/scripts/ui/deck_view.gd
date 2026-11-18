class_name DeckView
extends Control
## Full-screen layer behind the UI: the ship's deck from top_y down, with masts on either side.
##
## The deck has hundreds of small shapes, so it is drawn once into a SubViewport texture and that
## one image is rocked about `pivot` (see ShipMotion). Drawing the shapes every frame was the main
## cause of lag. Everything else standing on the deck rocks with the same motion.

const PAD_X: float = 220.0  # extra width on each side so rocking never shows an edge
const PAD_UP: float = 430.0  # room above the rail for the masts
const PAD_DOWN: float = 320.0

var top_y: float = 600.0:
	set(value):
		if is_equal_approx(top_y, value):
			return
		top_y = value
		_rebuild()
var pivot: Vector2 = Vector2(270.0, 720.0)

var _viewport: SubViewport
var _art: Control
var _image: TextureRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)
	_art = Control.new()
	_art.draw.connect(_draw_art)
	_viewport.add_child(_art)
	_image = TextureRect.new()
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image.stretch_mode = TextureRect.STRETCH_SCALE
	_image.texture = _viewport.get_texture()
	add_child(_image)
	resized.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	if _viewport == null:
		return
	var w := size.x + PAD_X * 2.0
	var h := PAD_UP + maxf(0.0, size.y - top_y) + PAD_DOWN
	_viewport.size = Vector2i(int(w), int(h))
	_art.size = Vector2(w, h)
	_image.position = Vector2(-PAD_X, top_y - PAD_UP)
	_image.size = Vector2(w, h)
	_art.queue_redraw()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _draw_art() -> void:
	var w := size.x
	var width := _art.size.x
	_art.draw_set_transform(Vector2(PAD_X, PAD_UP))
	DeckArt.draw_masts(_art, w, 0.0, minf(top_y, 420.0))
	DeckArt.draw_deck(_art, Rect2(-PAD_X, 0.0, width, _art.size.y - PAD_UP), 0.0)
	_art.draw_set_transform(Vector2.ZERO)


func _process(_delta: float) -> void:
	var t := float(Time.get_ticks_msec()) / 1000.0
	# Same motion as ShipMotion.transform(): roll about the pivot plus a small bob.
	_image.pivot_offset = pivot - _image.position
	_image.rotation = ShipMotion.roll(t)
	_image.position = Vector2(-PAD_X, top_y - PAD_UP + ShipMotion.bob(t))
