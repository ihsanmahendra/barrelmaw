class_name SafeArea
extends RefCounted
## Space a phone keeps for itself at the screen edges (notch, status bar, home bar), in viewport units.
## Content that must stay readable (titles, buttons, text) is moved in by these amounts. The background
## still fills the whole screen. Zero on desktop.
##
## On the web the page measures CSS env(safe-area-inset-*) (see web/shell.html) and Godot converts it to units;
## on a phone build it asks the display. --safe=left,top,right,bottom (units) fakes it for testing.

static var debug_insets: Vector4 = Vector4.ZERO  # left, top, right, bottom


## Insets for a viewport of the given size in units.
static func insets(viewport_size: Vector2) -> Vector4:
	if debug_insets != Vector4.ZERO:
		return debug_insets
	var raw := Vector4.ZERO
	if OS.has_feature("web"):
		var res: Variant = JavaScriptBridge.eval("window.barrelmawSafe ? window.barrelmawSafe() : ''", true)
		var parts := str(res).split(",")
		if parts.size() >= 6 and float(parts[4]) > 0.0 and float(parts[5]) > 0.0:
			var sx := viewport_size.x / float(parts[4])
			var sy := viewport_size.y / float(parts[5])
			raw = Vector4(float(parts[0]) * sx, float(parts[1]) * sy, float(parts[2]) * sx, float(parts[3]) * sy)
	elif OS.has_feature("mobile"):
		var area := DisplayServer.get_display_safe_area()
		var screen := DisplayServer.screen_get_size()
		var win := DisplayServer.window_get_size()
		if win.x > 0 and win.y > 0:
			var sx2 := viewport_size.x / float(win.x)
			var sy2 := viewport_size.y / float(win.y)
			raw = Vector4(area.position.x * sx2, area.position.y * sy2, (screen.x - area.end.x) * sx2, (screen.y - area.end.y) * sy2)
	# A sane limit: a broken value must not push the whole game off the screen.
	return Vector4(clampf(raw.x, 0.0, 120.0), clampf(raw.y, 0.0, 140.0), clampf(raw.z, 0.0, 120.0), clampf(raw.w, 0.0, 100.0))
