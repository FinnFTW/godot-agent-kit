extends SceneTree
## Checks the whole project loads cleanly, without opening the editor: every script parses
## and every scene and resource file loads, and nothing pushes an error on the way.
## The thing an agent runs after a batch of edits, before calling the work done.
##
##   godot --headless --path <project> --import                    (once, so class_names exist)
##   godot --headless --path <project> -s res://addons/agent_kit/check_project.gd [-- options]
##
## Options after `--`:
##   --skip=<prefix,prefix>   res:// paths to leave alone (default: res://addons,res://.godot)
##   --scripts-only           do not load scenes and resources
##   --quiet                  print only problems and the summary
##
## Prints one line per problem (file, then the errors Godot reported while loading it) and
## exits 1 if there was any. Loading a scene instantiates nothing, so _ready code never runs;
## what this catches is parse errors, missing dependencies, broken ext_resource paths and
## scripts that fail to compile.

const RunTests = preload("res://addons/agent_kit/run_tests.gd")

var _skip: PackedStringArray = PackedStringArray(["res://addons", "res://.godot"])
var _scripts_only: bool = false
var _quiet: bool = false
var _errors := RunTests.ErrorCatcher.new()


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--skip="):
			_skip = arg.trim_prefix("--skip=").split(",", false)
		elif arg == "--scripts-only":
			_scripts_only = true
		elif arg == "--quiet":
			_quiet = true
	OS.add_logger(_errors)
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var files: Array[String] = []
	_find("res://", files)
	files.sort()
	var checked: int = 0
	var problems: int = 0
	_errors.take()
	for path in files:
		var ext: String = path.get_extension()
		var is_script: bool = ext == "gd"
		var is_data: bool = ext in ["tscn", "tres", "scn", "res"]
		if not is_script and (not is_data or _scripts_only):
			continue
		checked += 1
		var res: Resource = load(path)
		var caught: Array[Dictionary] = _errors.take()
		var bad: bool = res == null or not caught.is_empty()
		if is_script and res != null and not (res as GDScript).can_instantiate():
			bad = true
		if bad:
			problems += 1
			print("PROBLEM  %s%s" % [path, "  (did not load)" if res == null else ""])
			for e in caught:
				print("         %s  [%s]" % [e["text"], e["where"]])
		elif not _quiet:
			print("ok       %s" % path)
	print("")
	print("%d files checked, %d with problems" % [checked, problems])
	quit(1 if problems > 0 else 0)


func _find(dir_path: String, out: Array[String]) -> void:
	for prefix in _skip:
		if dir_path == prefix or dir_path.begins_with(prefix.trim_suffix("/") + "/"):
			return
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if d.current_is_dir():
			if not name.begins_with("."):
				_find(full, out)
		else:
			out.append(full)
		name = d.get_next()
	d.list_dir_end()
