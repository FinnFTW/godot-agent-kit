extends Node
## Screenshot on launch, so an agent can look at the game without a human at the screen.
## Add this node to your main scene (or as an autoload) and run the game, not headless:
##
##   godot --path <project> -- --screenshot=<out.png> [--screenshot-frames=30]
##
## After that many drawn frames (default 30, enough for the first scene to settle) it saves
## the main viewport to the PNG and quits. Without `--screenshot=` it does nothing, so it is
## safe to leave in a shipped game. The path may be absolute or `user://`-relative.
##
## Screenshots need a window and a GPU; `--headless` produces a black image or none. On a
## machine with no display, run with `--rendering-driver opengl3` and a virtual display.

var _path: String = ""
var _frames: int = 30
var _seen: int = 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			_path = arg.trim_prefix("--screenshot=")
		elif arg.begins_with("--screenshot-frames="):
			_frames = int(arg.trim_prefix("--screenshot-frames="))
	if _path == "":
		set_process(false)


func _process(_delta: float) -> void:
	_seen += 1
	if _seen < _frames:
		return
	set_process(false)
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var dir: String = ProjectSettings.globalize_path(_path).get_base_dir()
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)
	var err: Error = image.save_png(_path)
	if err == OK:
		print("Saved screenshot to %s (%dx%d)" % [_path, image.get_width(), image.get_height()])
	else:
		push_error("screenshot: could not save %s (error %d)" % [_path, err])
	get_tree().quit(0 if err == OK else 1)
