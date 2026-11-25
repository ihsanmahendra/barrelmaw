extends SceneTree
## Saves a picture of the real window at its real size (unlike --write-movie, which always records 540x960).
## godot --path . --resolution 390x844 --script res://tests/shot_tool.gd -- --out=/tmp/a.png --frames=40 <game debug flags>

func _initialize() -> void:
	var out := "/tmp/shot.png"
	var frames := 40
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.get_slice("=", 1)
		if a.begins_with("--frames="):
			frames = int(a.get_slice("=", 1))
	var scene: PackedScene = load(str(ProjectSettings.get_setting("application/run/main_scene")))
	root.add_child(scene.instantiate())
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out)
	print("SHOT ", img.get_size(), " viewport units ", root.get_visible_rect().size)
	quit()
