extends "res://addons/agent_kit/test_case.gd"
## A suite that must FAIL, used to prove the runner exits 1 and catches crashes:
##   godot --headless --path . -s res://addons/agent_kit/run_tests.gd -- --dir=res://demo/failing_suite
## Lives under demo/, not tests/, so the real suite never picks it up.


func test_plain_failure() -> void:
	expect_eq(1, 2, "one is not two")


func test_unexpected_push_error_fails() -> void:
	push_error("nobody expected this")


func test_script_crash_is_caught() -> void:
	var nothing: Node = null
	nothing.get_name()  # a script error: the test stops here and must be reported as a crash
	expect_true(true, "never reached")


func test_this_one_passes() -> void:
	expect_true(true, "control")
