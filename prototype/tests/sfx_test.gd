extends SceneTree
## Sound effects must not be cut off by later ones (a big volley stacks about ten at once).
##   Godot --headless --path . --script res://tests/sfx_test.gd

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	_run()


## True while the named sound is still sounding on some player.
func _is_sounding(sfx: Sfx, sound: String) -> bool:
	for p in sfx.get_children():
		if p.playing and p.stream.resource_path.get_file() == sound + ".wav":
			return true
	return false


func _stop_all(sfx: Sfx) -> void:
	for p in sfx.get_children():
		p.stop()


func _run() -> void:
	var sfx := Sfx.new()
	root.add_child(sfx)
	await process_frame

	# The cannon blast at the start of a volley survives the shots, hits and new cards that follow it.
	sfx.play("cannon")
	for i in 11:
		sfx.play("hit")
	check(_is_sounding(sfx, "cannon"), "cannon is cut off when 12 sounds overlap")

	# Short sounds that already finished are reused first, so a long one plays to its end.
	_stop_all(sfx)
	await process_frame
	sfx.play("sting_transcended")  # 1.8 s
	for i in 20:
		sfx.play("click")  # 0.05 s
		await create_timer(0.07).timeout
	check(_is_sounding(sfx, "sting_transcended"), "a long sound is cut off by 20 short ones played one after another")

	_stop_all(sfx)
	sfx.queue_free()
	await create_timer(0.1).timeout
	print("Sfx test failures: ", failures)
	quit(1 if failures > 0 else 0)
