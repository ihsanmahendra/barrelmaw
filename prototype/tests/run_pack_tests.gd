## Runs only the card pack checks (fast). godot --headless --path prototype --script res://tests/run_pack_tests.gd
extends SceneTree
func _init() -> void:
	GameData.ensure_loaded()
	var t := PackTests.new()
	t.run()
	print("Pack failures: ", t.failures)
	quit(1 if t.failures > 0 else 0)
