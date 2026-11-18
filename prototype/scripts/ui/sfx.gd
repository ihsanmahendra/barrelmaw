class_name Sfx
extends Node
## Plays short sound effects from res://audio through a small pool of players.

const NAMES: Array = ["click", "card", "deal", "sparkle", "fire", "hit", "big", "boom", "miss", "win", "lose", "reward", "cannon"]
const POOL_SIZE: int = 8

static var muted: bool = false

var _streams: Dictionary = {}
var _players: Array = []
var _next: int = 0


func _ready() -> void:
	for n in NAMES:
		_streams[n] = load("res://audio/%s.wav" % n)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


## Plays a named effect. pitch varies the playback speed; delay (seconds) postpones it.
func play(sound: String, pitch: float = 1.0, delay: float = 0.0) -> void:
	if muted or not _streams.has(sound):
		return
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
		if muted:
			return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[sound]
	p.pitch_scale = pitch
	p.play()
