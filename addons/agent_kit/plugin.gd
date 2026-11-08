@tool
extends EditorPlugin
## Agent Kit's editor side. Everything in this addon is meant to run headless, from the
## command line, so the editor plugin only adds two convenience entries to Project > Tools:
## run the tests, and check the whole project. Both start a second Godot process (the one
## running this editor) and print its output to the Output panel.

const RUN_TESTS := "Agent Kit: run tests"
const CHECK_PROJECT := "Agent Kit: check project"


func _enter_tree() -> void:
	add_tool_menu_item(RUN_TESTS, _run_tests)
	add_tool_menu_item(CHECK_PROJECT, _check_project)


func _exit_tree() -> void:
	remove_tool_menu_item(RUN_TESTS)
	remove_tool_menu_item(CHECK_PROJECT)


func _run_tests() -> void:
	_run_headless("res://addons/agent_kit/run_tests.gd", [])


func _check_project() -> void:
	_run_headless("res://addons/agent_kit/check_project.gd", [])


## Runs `script` headless in a second Godot process on this project and prints what it
## printed. Blocking (the editor waits), which is fine for a test suite that takes seconds
## to a minute; for longer suites use the command line.
func _run_headless(script: String, extra: PackedStringArray) -> void:
	var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", script])
	if not extra.is_empty():
		args.append("--")
		args.append_array(extra)
	var output: Array = []
	print("Agent Kit: running %s ..." % script)
	var code: int = OS.execute(OS.get_executable_path(), args, output, true)
	for chunk in output:
		print(chunk)
	print("Agent Kit: exit code %d" % code)
