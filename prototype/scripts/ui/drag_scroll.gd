class_name DragScroll
extends ScrollContainer
## A vertical scroll list you can drag from anywhere, with a little coasting after you let go.
##
## A plain ScrollContainer cannot be dragged from a button, a card or a panel: those controls take the touch
## themselves and the list never sees it. DragScroll listens to the controls inside it (call wire() once the
## content is built), starts scrolling when the finger moves more than a few pixels, and cancels the press of a
## button that was being dragged so the drag does not tap it.

const SLOP: float = 10.0  # pixels a finger must move before a press becomes a drag
const COAST_DECAY: float = 4.0  # how fast the coasting slows down (per second)
const COAST_MIN: float = 40.0  # pixels per second below which coasting stops
const MAX_SPEED: float = 3000.0  # fastest coast, pixels per second

var _down: bool = false
var _active: bool = false
var _start_y: float = 0.0
var _start_scroll: float = 0.0
var _last_y: float = 0.0
var _last_ms: int = 0
var _velocity: float = 0.0
var _coast: float = 0.0
var _pos_f: float = 0.0
var _press_ctl: Control = null
var _last_key: String = ""


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll_deadzone = 100000  # the built-in touch drag is replaced by this one
	gui_input.connect(_on_input.bind(null))


## Listens to every control under `root` that would otherwise swallow a touch (panels, buttons, cards).
func wire(root: Node) -> void:
	for n in _descendants(root):
		var ctl := n as Control
		if ctl != null and ctl.mouse_filter == Control.MOUSE_FILTER_STOP:
			var cb := _on_input.bind(ctl)
			if not ctl.gui_input.is_connected(cb):
				ctl.gui_input.connect(cb)


func _descendants(node: Node, out: Array = []) -> Array:
	out.append(node)
	for c in node.get_children():
		_descendants(c, out)
	return out


func _on_input(event: InputEvent, source: Control) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		var key := "b%d_%d_%s" % [Engine.get_process_frames(), int(mb.pressed), str(mb.global_position)]
		if key == _last_key:
			return
		_last_key = key
		if mb.pressed:
			_begin(mb.global_position.y, source)
		else:
			_end()
	elif event is InputEventMouseMotion and _down:
		var mm := event as InputEventMouseMotion
		var key2 := "m%d_%s" % [Engine.get_process_frames(), str(mm.global_position)]
		if key2 == _last_key:
			return
		_last_key = key2
		_move(mm.global_position.y)


func _begin(y: float, source: Control) -> void:
	# A touch while the list is still coasting only stops it, like on a phone: it must not press a button.
	if absf(_coast) >= COAST_MIN and source is BaseButton:
		_cancel_press.call_deferred(source)  # deferred: the button has not handled this press yet
	_down = true
	_active = false
	_start_y = y
	_last_y = y
	_last_ms = Time.get_ticks_msec()
	_start_scroll = float(scroll_vertical)
	_velocity = 0.0
	_coast = 0.0
	_press_ctl = source


func _move(y: float) -> void:
	if not _active:
		if absf(y - _start_y) < SLOP:
			return
		_active = true
		# The finger is dragging the list, not pressing: take the press away from the button under it.
		if _press_ctl is BaseButton:
			_cancel_press(_press_ctl)
	scroll_vertical = int(_start_scroll - (y - _start_y))
	var now := Time.get_ticks_msec()
	var dt := maxf(float(now - _last_ms) / 1000.0, 0.016)  # a move event a millisecond after the last is not a flick
	_velocity = clampf(lerpf(_velocity, (y - _last_y) / dt, 0.4), -MAX_SPEED, MAX_SPEED)
	_last_y = y
	_last_ms = now


## Clears a button's half-finished press so releasing the finger over it does not tap it.
func _cancel_press(btn: Control) -> void:
	var b := btn as BaseButton
	if b != null and is_instance_valid(b):
		b.disabled = true
		b.disabled = false


func _end() -> void:
	if _down and _active and Time.get_ticks_msec() - _last_ms < 120:
		_coast = _velocity
		_pos_f = float(scroll_vertical)
	_down = false
	_active = false
	_press_ctl = null


func _process(delta: float) -> void:
	if _coast == 0.0 or _down:
		return
	_pos_f -= _coast * delta
	scroll_vertical = int(_pos_f)
	_coast *= exp(-COAST_DECAY * delta)
	var bar := get_v_scroll_bar()
	if absf(_coast) < COAST_MIN or _pos_f <= 0.0 or _pos_f >= bar.max_value - bar.page:
		_coast = 0.0
