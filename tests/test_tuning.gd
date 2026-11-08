extends "res://tests/test_case.gd"
## The tuning lints and the tuning sheet, run against the demo tuning file.

const SCRIPT := "res://demo/tuning/demo_tuning.gd"
const TRES := "res://demo/tuning/demo.tres"
const Sheet = preload("res://addons/agent_kit/tuning_sheet.gd")


func test_demo_tuning_is_fully_described() -> void:
	expect_every_setting_described(SCRIPT, true)


func test_demo_tres_only_writes_real_settings() -> void:
	expect_tres_matches_script(TRES, SCRIPT)


func test_tooltip_problem_catches_each_shape() -> void:
	var TC = load("res://addons/agent_kit/test_case.gd")
	expect_eq(TC.tooltip_problem("How fast it goes: metres per second"), "", "good line passes")
	expect_contains(TC.tooltip_problem("No colon here"), "no colon", "missing colon")
	expect_contains(TC.tooltip_problem("run_speed: m/s"), "names code", "underscore before colon")
	expect_contains(TC.tooltip_problem("Goes 60 fast: m/s"), "number", "digit before colon")
	expect_contains(TC.tooltip_problem("One. Two: m/s"), "more than one sentence", "two sentences")


func test_sheet_lists_every_setting_with_default_and_text() -> void:
	var text: String = Sheet.build(PackedStringArray(["res://demo/tuning"]), PackedStringArray(), "Demo")
	expect_contains(text, "# Demo: the tuning sheet", "title")
	expect_contains(text, "| Run Speed | 6 | How fast the player runs | metres per second of top speed on flat ground. |", "run_speed row uses the script default, not the .tres value")
	expect_contains(text, "| Slow Motion | on |", "bool shown as on/off")
	expect_contains(text, "### Demo — Feel", "export groups become sub-headings")
	expect_contains(text, "demo/tuning/demo.tres", "the .tres file is named")
	var n: int = Sheet.rows(Sheet.sections(PackedStringArray(["res://demo/tuning"]), PackedStringArray())).size()
	expect_eq(n, 5, "five settings on the sheet")


func test_a_missing_description_fails_the_lint() -> void:
	var c: RefCounted = (load("res://addons/agent_kit/test_case.gd") as GDScript).new()
	c.expect_every_setting_described("res://tests/fixtures/bad_tuning.gd", true)
	expect_eq(c._failures.size(), 2, "undescribed setting and a bad tooltip both fail")
	expect_contains(c._failures[0], "has no '##' description", "the undescribed one")
	expect_contains(c._failures[1], "number before the colon", "the numeric one")
