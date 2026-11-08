extends SceneTree
## Runs every automated test without opening the game.
##
##   godot --headless --path <project> --import                    (once, so class_names exist)
##   godot --headless --path <project> -s res://addons/agent_kit/run_tests.gd [-- options]
##
## Options after `--`:
##   --only=<text>        run only files whose path contains <text>
##   --dir=<res path>     where the tests live (default res://tests)
##   --real-time-only     run only files that declare `const REAL_TIME := true`
##   --junit=<path>       also write a JUnit XML report (for CI)
##   --quiet              print only failures and the summary
##
## Finds every <dir>/**/test_*.gd, runs each "test_" method, prints PASS / FAIL / SKIP, and
## exits with code 1 if anything failed, so it can gate commits and CI.
##
## A test fails on a failed expect_*, and on any error Godot reports while it runs: a script
## error (a crash; the test function just stops there, which otherwise looks like a pass)
## always, a push_error or engine error unless the test called expect_error() for it. A file
## that does not load fails too.
##
## Fast and steady: run with `--fixed-fps 120` and every frame is exactly one physics tick,
## so the suite runs as fast as the computer can and a busy computer cannot change a result.
## Files that need real time (a real network connection) declare `const REAL_TIME := true`;
## at fixed speed they are skipped, and `--real-time-only` runs just them without --fixed-fps.

const TestCaseScript = preload("res://addons/agent_kit/test_case.gd")


## Hears every error Godot reports (OS.add_logger), so the runner can pin it on the test
## that was running. Warnings are left alone.
class ErrorCatcher extends Logger:
	var _lock := Mutex.new()
	var _caught: Array[Dictionary] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, script_backtrace: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		var text: String = code if rationale == "" else "%s (%s)" % [rationale, code]
		var where: String = "%s:%d in %s" % [file, line, function]
		for bt in script_backtrace:
			if bt.get_frame_count() > 0:
				where = "%s:%d in %s" % [bt.get_frame_file(0), bt.get_frame_line(0), bt.get_frame_function(0)]
				break
		_lock.lock()
		_caught.append({"script": error_type == ERROR_TYPE_SCRIPT, "text": text, "where": where})
		_lock.unlock()

	## The errors caught since the last call, oldest first.
	func take() -> Array[Dictionary]:
		_lock.lock()
		var out: Array[Dictionary] = _caught.duplicate()
		_caught.clear()
		_lock.unlock()
		return out


var _only: String = ""
var _dir: String = "res://tests"
var _real_time_only: bool = false
var _junit: String = ""
var _quiet: bool = false
var _fixed_fps: bool = false

var _passed: int = 0
var _failed: int = 0
var _skipped: int = 0
var _results: Array[Dictionary] = []  # {file, name, status, details: Array[String], ms}
var _errors := ErrorCatcher.new()


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=")
		elif arg.begins_with("--dir="):
			_dir = arg.trim_prefix("--dir=")
		elif arg == "--real-time-only":
			_real_time_only = true
		elif arg.begins_with("--junit="):
			_junit = arg.trim_prefix("--junit=")
		elif arg == "--quiet":
			_quiet = true
	_fixed_fps = "--fixed-fps" in OS.get_cmdline_args()
	OS.add_logger(_errors)
	# Wait one frame so autoloads exist before any test touches them.
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var started: int = Time.get_ticks_msec()
	var files: Array[String] = []
	_find_tests(_dir, files)
	files.sort()
	if files.is_empty():
		print("No test files found under %s (%s/**/test_*.gd)." % [_dir, _dir])
	for path in files:
		if _only != "" and not path.contains(_only):
			continue
		await _run_file(path)
	print("")
	print("%d passed, %d failed, %d skipped  (%.1f s)" % [_passed, _failed, _skipped, (Time.get_ticks_msec() - started) / 1000.0])
	if _junit != "":
		_write_junit()
	quit(1 if _failed > 0 else 0)


func _find_tests(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if d.current_is_dir():
			if not name.begins_with("."):
				_find_tests(full, out)
		elif name.begins_with("test_") and name.ends_with(".gd") and name != "test_case.gd":
			out.append(full)
		name = d.get_next()
	d.list_dir_end()


func _label(path: String) -> String:
	return path.trim_prefix(_dir + "/").trim_prefix("res://")


func _run_file(path: String) -> void:
	_errors.take()
	var script: GDScript = load(path)
	if script == null or not script.can_instantiate():
		var details: Array[String] = []
		for e in _errors.take():
			details.append("%s  [%s]" % [e["text"], e["where"]])
		_record(path, "(load)", "FAIL", details, 0.0, "could not load script")
		return
	var probe = script.new()
	if not (probe is TestCaseScript):
		_record(path, "(file)", "SKIP", [], 0.0, "does not extend res://addons/agent_kit/test_case.gd")
		return
	var real_time: bool = script.get_script_constant_map().get("REAL_TIME", false) == true
	if _real_time_only and not real_time:
		return
	if real_time and _fixed_fps and not _real_time_only:
		_record(path, "(file)", "SKIP", [], 0.0, "needs real time; run with --real-time-only and no --fixed-fps")
		return
	for m in script.get_script_method_list():
		var method: String = m["name"]
		if not method.begins_with("test_"):
			continue
		var case = script.new()
		case.tree = self
		_errors.take()
		var t0: int = Time.get_ticks_usec()
		case.before_each()
		await case.call(method)
		case.after_each()
		case._cleanup()
		var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
		var errored: bool = case._judge_errors(_errors.take())
		if case._skip_reason != "" and not errored and case._failures.is_empty():
			_record(path, method, "SKIP", [], ms, case._skip_reason)
		elif case._failures.is_empty():
			_record(path, method, "PASS", [], ms, "")
		else:
			var details: Array[String] = []
			details.assign(case._failures)
			_record(path, method, "FAIL", details, ms, "")


func _record(path: String, method: String, status: String, details: Array[String], ms: float, note: String) -> void:
	_results.append({"file": path, "name": method, "status": status, "details": details, "ms": ms, "note": note})
	var label := "%s :: %s" % [_label(path), method]
	match status:
		"PASS":
			_passed += 1
			if not _quiet:
				print("PASS  %s" % label)
		"SKIP":
			_skipped += 1
			if not _quiet:
				print("SKIP  %s (%s)" % [label, note])
		"FAIL":
			_failed += 1
			print("FAIL  %s%s" % [label, (" :: " + note) if note != "" else ""])
			for line in details:
				print("        " + line)


func _write_junit() -> void:
	var f := FileAccess.open(_junit, FileAccess.WRITE)
	if f == null:
		push_error("run_tests: cannot write %s" % _junit)
		return
	f.store_line('<?xml version="1.0" encoding="UTF-8"?>')
	f.store_line('<testsuite name="godot" tests="%d" failures="%d" skipped="%d">' % [_results.size(), _failed, _skipped])
	for r in _results:
		f.store_line('  <testcase classname="%s" name="%s" time="%.3f">' % [_xml(_label(r["file"])), _xml(r["name"]), r["ms"] / 1000.0])
		if r["status"] == "FAIL":
			var text: String = "\n".join(r["details"]) if not r["details"].is_empty() else r["note"]
			f.store_line('    <failure message="%s"></failure>' % _xml(text))
		elif r["status"] == "SKIP":
			f.store_line('    <skipped message="%s"/>' % _xml(r["note"]))
		f.store_line('  </testcase>')
	f.store_line('</testsuite>')
	f.close()
	print("Wrote %s" % _junit)


static func _xml(s: String) -> String:
	return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")
