extends "res://tests/test_case.gd"
## The runner turns engine errors into failures, and expect_error() lets a test provoke one.


func test_expected_push_error_passes() -> void:
	expect_error("meant to happen")
	push_error("this error was meant to happen")


func test_judge_marks_unexpected_errors_as_failures() -> void:
	var c: RefCounted = (load("res://addons/agent_kit/test_case.gd") as GDScript).new()
	var caught: Array[Dictionary] = [
		{"script": false, "text": "something broke", "where": "a.gd:1 in f"},
		{"script": true, "text": "Invalid call", "where": "b.gd:2 in g"},
	]
	var added: bool = c._judge_errors(caught)
	expect_true(added, "judge reports it added failures")
	expect_eq(c._failures.size(), 2, "one failure per error")
	expect_contains(c._failures[0], "unexpected error", "engine error labelled unexpected")
	expect_contains(c._failures[1], "crashed", "script error labelled as a crash")


func test_judge_accepts_expected_error_and_demands_it() -> void:
	var c: RefCounted = (load("res://addons/agent_kit/test_case.gd") as GDScript).new()
	c.expect_error("foo")
	var one: Array[Dictionary] = [{"script": false, "text": "a foo happened", "where": "x"}]
	var ok: bool = c._judge_errors(one)
	expect_false(ok, "a matching error adds no failure")
	var d: RefCounted = (load("res://addons/agent_kit/test_case.gd") as GDScript).new()
	d.expect_error("foo")
	var none: Array[Dictionary] = []
	d._judge_errors(none)
	expect_eq(d._failures.size(), 1, "an expected error that never came is a failure")


func test_skip_is_reported_not_passed() -> void:
	skip("demonstrates SKIP output; nothing is missing")
