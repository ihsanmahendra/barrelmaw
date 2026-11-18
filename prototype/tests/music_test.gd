extends SceneTree
## Prints the state of the music players a moment after the menu opens.
var main: Control
var step: int = 0


func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	step += 1
	if step == 90:
		var m: Music = main.music
		print("current: ", m.current, "  enabled: ", Music.enabled, "  muted: ", Sfx.muted)
		for i in m._players.size():
			var p: AudioStreamPlayer = m._players[i]
			print("player ", i, " playing=", p.playing, " vol=", p.volume_db, " stream=", p.stream, " bus=", p.bus)
		print("streams loaded: ", m._streams)
		quit(0)
	return false
