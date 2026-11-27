class_name Sfx
extends Node
## Plays short sound effects from res://audio through a small pool of players.

const NAMES: Array = ["click", "card", "deal", "sparkle", "fire", "hit", "big", "boom", "miss", "win", "lose", "reward", "cannon",
	"chest_shake", "chest_open", "flip", "sting_common", "sting_rare", "sting_epic", "sting_legendary", "sting_transcended", "merge", "pearl", "drumroll", "crew_cheer", "strike_ghost", "strike_armor", "strike_curse"]
const POOL_SIZE: int = 16  # a big volley stacks about ten sounds at once

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
	var p := _free_player()
	p.stream = _streams[sound]
	p.pitch_scale = pitch
	p.play()


## The next silent player, so a new sound does not cut off one that is still playing.
## Only when every player is busy is one reused, in turn.
func _free_player() -> AudioStreamPlayer:
	var pick: int = _next
	for i in _players.size():
		var k: int = (_next + i) % _players.size()
		if not _players[k].playing:
			pick = k
			break
	_next = (pick + 1) % _players.size()
	return _players[pick]
