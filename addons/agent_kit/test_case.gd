extends RefCounted
## Base for every test file. A test file is any tests/**/test_*.gd that extends this script
## (by path: `extends "res://addons/agent_kit/test_case.gd"`, or extends your own
## tests/test_case.gd that does); every method starting with "test_" is one test.
## Use the expect_* helpers; a test with no failures is a PASS.
## Tests may `await` (wait_frames, wait_physics, or `await tree.process_frame`) when they
## need the engine to run.
##
## A test also fails on any error Godot reports while it runs (see run_tests.gd): a script
## error always; a push_error or engine error unless the test called expect_error() for it.

## The running SceneTree, for tests that add nodes. Pure logic tests ignore it.
var tree: SceneTree

var _failures: Array[String] = []
var _spawned: Array[Node] = []
var _skip_reason: String = ""
var _expected_errors: Array[String] = []


# ---------------------------------------------------------------- expectations

func fail(what: String) -> void:
	_failures.append(what)


func expect_true(value: bool, what: String) -> void:
	if not value:
		_failures.append("expected true: " + what)


func expect_false(value: bool, what: String) -> void:
	if value:
		_failures.append("expected false: " + what)


func expect_eq(actual: Variant, expected: Variant, what: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [what, str(expected), str(actual)])


func expect_ne(actual: Variant, unexpected: Variant, what: String) -> void:
	if actual == unexpected:
		_failures.append("%s: expected anything but %s" % [what, str(unexpected)])


func expect_near(actual: float, expected: float, tolerance: float, what: String) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s: expected %.3f (+/- %.3f), got %.3f" % [what, expected, tolerance, actual])


func expect_gt(actual: float, floor_value: float, what: String) -> void:
	if actual <= floor_value:
		_failures.append("%s: expected more than %.3f, got %.3f" % [what, floor_value, actual])


func expect_lt(actual: float, ceiling: float, what: String) -> void:
	if actual >= ceiling:
		_failures.append("%s: expected less than %.3f, got %.3f" % [what, ceiling, actual])


func expect_contains(haystack: Variant, needle: Variant, what: String) -> void:
	var ok: bool = false
	match typeof(haystack):
		TYPE_STRING, TYPE_STRING_NAME:
			ok = String(haystack).contains(String(needle))
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, \
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			ok = needle in haystack
		TYPE_DICTIONARY:
			ok = haystack.has(needle)
	if not ok:
		_failures.append("%s: %s does not contain %s" % [what, str(haystack), str(needle)])


## This test provokes an error on purpose (a "fails loudly" check): a push_error or engine
## error whose text contains `part` does not fail it, and the test fails if none comes.
func expect_error(part: String) -> void:
	_expected_errors.append(part)


## Mark this test as waiting on something honestly not built yet. The runner prints SKIP
## with the reason instead of PASS. Never to hide a real failure.
func skip(reason: String) -> void:
	_skip_reason = reason


# ---------------------------------------------------------------- the engine

## Called before / after each test. Override if a test file needs setup.
func before_each() -> void:
	pass


func after_each() -> void:
	pass


## Let the game run for `n` physics ticks. Use with await.
func wait_physics(n: int) -> void:
	for i in n:
		await tree.physics_frame


## Wait for `n` drawn frames: for things done in _process. Use with await.
func wait_frames(n: int) -> void:
	for i in n:
		await tree.process_frame


## A fresh empty node under the tree root, freed automatically when the test ends.
func new_world() -> Node:
	return _spawn(Node.new())


func new_world_2d() -> Node2D:
	return _spawn(Node2D.new()) as Node2D


func new_world_3d() -> Node3D:
	return _spawn(Node3D.new()) as Node3D


## A fresh 3D world with its OWN physics and visuals (nothing from other worlds bumps into
## it). One per pretend computer in multiplayer tests. Freed when the test ends.
func new_separate_world_3d() -> Node3D:
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.size = Vector2i(64, 64)
	_spawn(vp)
	var w := Node3D.new()
	w.name = "World"
	vp.add_child(w)
	return w


## Adds `node` under the tree root and frees it when the test ends. Returns it.
func _spawn(node: Node) -> Node:
	tree.root.add_child(node)
	_spawned.append(node)
	return node


# ---------------------------------------------------------------- tuning / data lints

## Every exported setting in a tuning script (`@export var`, `@export_range(...) var`, ...)
## has one "##" line directly above it that describes it: the Inspector shows that line as the
## tooltip. Pass `strict = true` to also demand the two-part shape that reads well to a
## non-programmer: "What you would notice: what it actually does" (plain phrase before the
## colon, under 60 characters, no code names or numbers).
func expect_every_setting_described(script_path: String, strict: bool = false) -> void:
	var source: String = FileAccess.get_file_as_string(script_path)
	if source == "":
		fail("%s: cannot read" % script_path)
		return
	var lines: PackedStringArray = source.split("\n")
	var export_re: RegEx = RegEx.create_from_string(r"^@export(?:_\w+(?:\([^)]*\))?)?\s+var\s+(\w+)")
	var settings: int = 0
	for i in lines.size():
		var m: RegExMatch = export_re.search(lines[i].strip_edges())
		if m == null:
			continue
		settings += 1
		var setting: String = m.get_string(1)
		var above: String = lines[i - 1].strip_edges() if i > 0 else ""
		if not above.begins_with("## ") or above.length() < 12:
			fail("%s: %s has no '##' description line above it" % [script_path, setting])
			continue
		if strict:
			if i > 1 and lines[i - 2].strip_edges().begins_with("##"):
				fail("%s: %s's '##' description runs over more than one line" % [script_path, setting])
			var problem: String = tooltip_problem(above.trim_prefix("## "))
			if problem != "":
				fail("%s: %s's tooltip %s" % [script_path, setting, problem])
	expect_gt(settings, 0, "exported settings found in %s" % script_path)


## What is wrong with a setting's tooltip line (the text after "## ") in strict mode, or ""
## when it has the shape: what you would notice, then a colon and what it actually does.
static func tooltip_problem(text: String) -> String:
	var colon: int = text.find(":")
	if colon < 0:
		return "has no colon: start with what you would notice, then ': ' and what it does"
	var plain: String = text.substr(0, colon)
	if plain.length() >= 60:
		return "starts with %d characters before the colon (keep what you would notice under 60): \"%s\"" % [plain.length(), plain]
	for bad in ["_", "`"]:
		if plain.contains(bad):
			return "names code before the colon ('%s'): \"%s\"" % [bad, plain]
	if RegEx.create_from_string(r"\d").search(plain) != null:
		return "has a number before the colon: \"%s\"" % plain
	if plain.contains(". "):
		return "has more than one sentence before the colon (one plain phrase, then ': '): \"%s\"" % plain
	return ""


## A .tres that uses `script_path` is checked against the script's `@export var`s: the file
## loads, and every value written in a section that uses the script is a real setting of it
## (a typo or a stale name fails). A setting that is NOT written is fine: the editor leaves
## out every value equal to the script's default when it saves.
func expect_tres_matches_script(tres_path: String, script_path: String) -> void:
	var re: RegEx = RegEx.create_from_string(r"^@export(?:_\w+(?:\([^)]*\))?)?\s+var (\w+)")
	var extends_re: RegEx = RegEx.create_from_string(r'^extends\s+(?:"([^"]+)"|(\w+))')
	var by_class: Dictionary = {}
	for entry in ProjectSettings.get_global_class_list():
		by_class[String(entry["class"])] = String(entry["path"])
	var settings: PackedStringArray = PackedStringArray()
	var own: int = 0
	var path: String = script_path
	var hops: int = 0
	while path != "" and hops < 32:
		hops += 1
		var parent: String = ""
		var src: String = FileAccess.get_file_as_string(path)
		if src == "":
			fail("%s: cannot read script %s" % [tres_path, path])
			return
		for line in src.split("\n"):
			var stripped: String = line.strip_edges()
			var m: RegExMatch = re.search(stripped)
			if m != null:
				settings.append(m.get_string(1))
				if path == script_path:
					own += 1
			var xm: RegExMatch = extends_re.search(stripped)
			if xm != null:
				parent = xm.get_string(1) if xm.get_string(1) != "" else by_class.get(xm.get_string(2), "")
		path = parent
	expect_gt(own, 0, "exported settings found in %s" % script_path)
	if load(tres_path) == null:
		fail("%s does not load" % tres_path)
		return
	var ext_re: RegEx = RegEx.create_from_string(r'^\[ext_resource type="Script".*path="([^"]+)".*id="([^"]+)"')
	var key_re: RegEx = RegEx.create_from_string(r"^([A-Za-z_][\w/]*) = (.*)$")
	var script_re: RegEx = RegEx.create_from_string(r'^script = ExtResource\("([^"]+)"\)')
	var ids: PackedStringArray = PackedStringArray()
	var sections: Array = []
	var current: PackedStringArray = PackedStringArray()
	var in_section: bool = false
	for raw in FileAccess.get_file_as_string(tres_path).split("\n"):
		var line: String = raw.strip_edges()
		var em: RegExMatch = ext_re.search(line)
		if em != null:
			if em.get_string(1) == script_path:
				ids.append(em.get_string(2))
			continue
		if line.begins_with("["):
			if in_section:
				sections.append(current)
			current = PackedStringArray()
			in_section = line.begins_with("[resource]") or line.begins_with("[sub_resource")
			continue
		if in_section and line != "":
			current.append(line)
	if in_section:
		sections.append(current)
	var checked: int = 0
	for section in sections:
		var uses_script: bool = false
		for line in section:
			var sm: RegExMatch = script_re.search(line)
			if sm != null and sm.get_string(1) in ids:
				uses_script = true
		if not uses_script:
			continue
		checked += 1
		for line in section:
			var km: RegExMatch = key_re.search(line)
			if km == null:
				continue
			var name: String = km.get_string(1)
			if name == "script" or name.begins_with("resource_") or name.begins_with("metadata/"):
				continue
			if not (name in settings):
				fail("%s writes %s, which is not a setting of %s" % [tres_path, name, script_path])
	if checked == 0:
		fail("%s has no section using %s" % [tres_path, script_path])


# ---------------------------------------------------------------- runner hooks

## Called by the runner after each test with the errors Godot reported during it (each
## {script, text, where}); turns them into failures: every script error, and every other
## error that matches none of this test's expect_error texts; then every expect_error text
## that matched nothing. Returns whether it added any failure.
func _judge_errors(caught: Array[Dictionary]) -> bool:
	var before: int = _failures.size()
	var seen: Dictionary = {}
	for e in caught:
		if e["script"]:
			_failures.append("crashed: %s  [%s]" % [e["text"], e["where"]])
			continue
		var matched: bool = false
		for part in _expected_errors:
			if String(e["text"]).contains(part):
				seen[part] = true
				matched = true
		if not matched:
			_failures.append("unexpected error: %s  [%s]" % [e["text"], e["where"]])
	for part in _expected_errors:
		if not seen.has(part):
			_failures.append("expected an error containing \"%s\", none came" % part)
	return _failures.size() > before


## Called by the runner after each test: frees anything the test spawned.
func _cleanup() -> void:
	for n in _spawned:
		if is_instance_valid(n):
			n.queue_free()
	_spawned.clear()
