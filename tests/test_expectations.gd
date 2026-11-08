extends "res://tests/test_case.gd"
## The expect_* helpers: each records a failure exactly when it should.


func _fresh() -> RefCounted:
	var c: RefCounted = (load("res://addons/agent_kit/test_case.gd") as GDScript).new()
	c.tree = tree
	return c


func test_passing_expectations_record_nothing() -> void:
	var c := _fresh()
	c.expect_true(true, "t")
	c.expect_false(false, "f")
	c.expect_eq(3, 3, "eq")
	c.expect_ne(3, 4, "ne")
	c.expect_near(1.0, 1.001, 0.01, "near")
	c.expect_gt(2.0, 1.0, "gt")
	c.expect_lt(1.0, 2.0, "lt")
	c.expect_contains("hello world", "world", "str")
	c.expect_contains([1, 2, 3], 2, "arr")
	c.expect_contains({"a": 1}, "a", "dict")
	expect_eq(c._failures.size(), 0, "no failures recorded")


func test_failing_expectations_record_one_each() -> void:
	var c := _fresh()
	c.expect_true(false, "t")
	c.expect_false(true, "f")
	c.expect_eq(3, 4, "eq")
	c.expect_ne(3, 3, "ne")
	c.expect_near(1.0, 2.0, 0.01, "near")
	c.expect_gt(1.0, 2.0, "gt")
	c.expect_lt(2.0, 1.0, "lt")
	c.expect_contains("hello", "xyz", "str")
	c.fail("plain")
	expect_eq(c._failures.size(), 9, "one failure per failed expectation")
	expect_contains(c._failures[2], "expected 4, got 3", "eq message names both values")


func test_spawned_nodes_are_freed_by_cleanup() -> void:
	var c := _fresh()
	var w: Node = c.new_world_2d()
	var w3: Node = c.new_world_3d()
	expect_true(w.is_inside_tree() and w3.is_inside_tree(), "worlds are in the tree")
	c._cleanup()
	await wait_frames(1)
	expect_false(is_instance_valid(w), "2D world freed after cleanup")
	expect_false(is_instance_valid(w3), "3D world freed after cleanup")


func test_wait_helpers_advance_the_engine() -> void:
	var before: int = Engine.get_process_frames()
	await wait_frames(2)
	expect_gt(Engine.get_process_frames(), before, "process frames advanced")
	var p_before: int = Engine.get_physics_frames()
	await wait_physics(2)
	expect_gt(Engine.get_physics_frames(), p_before, "physics frames advanced")
