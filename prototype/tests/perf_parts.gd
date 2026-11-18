extends SceneTree
## Hides one part of the battle screen at a time and prints draw calls and process time.
var main: Control
var step: int = 0
var samples: Array = []
var parts: Array = []
var hide_part: String = ""


func _initialize() -> void:
	SaveData.path = "user://debug_save.cfg"
	SaveData.reset()
	SaveData.tutorial_done = true
	for k in 20:
		SaveData.record(k, 2)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	parts = ["none", "deck_view", "queue_view", "board_view", "beach", "highlight", "hand_box", "hud"]


func _node_for(p: String) -> Node:
	match p:
		"deck_view": return main.deck_view
		"queue_view": return main.queue_view
		"board_view": return main.board_view
		"beach": return main.get_child(0)
		"highlight": return main.highlight
		"hand_box": return main.hand_box
		"hud": return main.hud
	return null


func _process(_d: float) -> bool:
	step += 1
	var phase := step / 120
	var local := step % 120
	if phase >= parts.size():
		quit(0)
		return false
	if local == 1:
		main._begin_stage(20, Stages.deck_for(20))
		samples.clear()
	if local == 20 and parts[phase] != "none":
		var n := _node_for(parts[phase])
		if n != null:
			n.visible = false
	if local > 50:
		samples.append([RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
	if local == 119:
		var dc := 0.0
		var tp := 0.0
		for s in samples:
			dc += s[0]; tp += s[1]
		print("hide %-12s draw calls %5.0f   process %5.2f ms" % [parts[phase], dc / samples.size(), tp / samples.size()])
	return false
