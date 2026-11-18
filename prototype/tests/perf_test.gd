extends SceneTree
## Prints draw calls and frame cost for each screen. Needs a window (not --headless):
## godot --path prototype --resolution 540x960 --script res://tests/perf_test.gd

var main: Control
var step: int = 0
var samples: Array = []
var current: String = ""
var plan: Array = []


func _initialize() -> void:
	SaveData.path = "user://debug_save.cfg"
	SaveData.reset()
	SaveData.tutorial_done = true
	for k in 20:
		SaveData.record(k, 2)
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	root.add_child(main)
	plan = [
		["menu", func() -> void: main.show_menu()],
		["map", func() -> void: main.show_map()],
		["battle", func() -> void: main._begin_stage(20, Stages.deck_for(20))],
		["battle-late", func() -> void: main._begin_stage(48, Stages.deck_for(48))],
	]


func _process(_d: float) -> bool:
	step += 1
	var phase := step / 150
	var local := step % 150
	if phase >= plan.size():
		quit(0)
		return false
	if local == 1:
		current = plan[phase][0]
		plan[phase][1].call()
		samples.clear()
	if local > 60:
		samples.append([
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		])
	if local == 149:
		var dc := 0.0
		var pr := 0.0
		var tp := 0.0
		var nodes := 0.0
		for s in samples:
			dc += s[0]; tp += s[1]; pr += s[2]; nodes = s[3]
		var n := float(samples.size())
		print("%-12s draw calls %6.0f   primitives %8.0f   process %5.2f ms   nodes %4.0f" % [current, dc / n, pr / n, tp / n, nodes])
	return false
