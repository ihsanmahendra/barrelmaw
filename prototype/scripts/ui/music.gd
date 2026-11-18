class_name Music
extends Node
## Background music: one looping track at a time with a short crossfade when it changes.
## Respects Sfx.muted (the sound switch) and its own Music.enabled switch (options menu).

const TRACKS: Dictionary = {"menu": "res://audio/bgm_menu.wav", "battle": "res://audio/bgm_battle.wav", "night": "res://audio/bgm_night.wav"}
const VOLUME_DB: float = -11.0
const FADE: float = 0.8

static var enabled: bool = true

var current: String = ""
var _unlocked: bool = not OS.has_feature("web")  # web browsers allow audio only after a tap
var _players: Array = []
var _active: int = 0
var _streams: Dictionary = {}


func _ready() -> void:
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -60.0
		p.finished.connect(_on_finished.bind(i))
		add_child(p)
		_players.append(p)
	for k in TRACKS:
		_streams[k] = load(TRACKS[k])


func _input(event: InputEvent) -> void:
	if _unlocked:
		return
	var tapped: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed) or (event is InputEventKey and event.pressed)
	if tapped:
		_unlocked = true
		# Start the music inside the same frame as the tap, which is when the browser allows it.
		_start_now()
		# Some browsers need a second nudge a moment later; this restarts nothing if it is playing.
		get_tree().create_timer(0.4).timeout.connect(_ensure_playing)


func _ensure_playing() -> void:
	var p: AudioStreamPlayer = _players[_active]
	if _is_audible() and current != "" and not p.playing:
		p.play()


func _start_now() -> void:
	if not _is_audible() or current == "" or not _streams.has(current):
		return
	var p: AudioStreamPlayer = _players[_active]
	p.stream = _streams[current]
	p.volume_db = VOLUME_DB
	p.play()


func _on_finished(i: int) -> void:
	# Restart the same track when it ends, so the music loops.
	if i == _active and current != "" and _is_audible():
		_players[i].play()


func _is_audible() -> bool:
	return enabled and not Sfx.muted


## Switches to the named track ("menu", "battle" or "night"). Does nothing if it is already playing.
func play_track(track: String) -> void:
	if track == current:
		return
	current = track
	_crossfade()


## Call after the sound or music switch changes.
func refresh() -> void:
	_crossfade()


func _crossfade() -> void:
	if not _unlocked:
		return  # waits for the first tap (see _input)
	var old: AudioStreamPlayer = _players[_active]
	if not _is_audible() or current == "" or not _streams.has(current):
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -60.0, FADE * 0.5)
		tw.tween_callback(old.stop)
		return
	_active = 1 - _active
	var nxt: AudioStreamPlayer = _players[_active]
	nxt.stream = _streams[current]
	nxt.volume_db = -60.0
	nxt.play()
	var tw2 := create_tween().set_parallel(true)
	tw2.tween_property(nxt, "volume_db", VOLUME_DB, FADE)
	if old.playing:
		tw2.tween_property(old, "volume_db", -60.0, FADE)
		tw2.chain().tween_callback(old.stop)
