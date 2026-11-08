# Rules for an AI coding agent working on this Godot project

Copy this file to your project root as `CLAUDE.md` (or `AGENTS.md`), fill in the two
placeholders, and delete this paragraph. It teaches the agent to verify its own work with
Agent Kit instead of telling you "done" and hoping.

## The project

<ONE PARAGRAPH: what the game is, the engine version, the language, who owns it.>

## The owner

- The owner wants to understand everything that changes, even when the agent writes most of
  the code. Explain every change in plain language: what changed, why, and what they should
  notice when they play.
- Gameplay feel is the owner's call. Do not add mechanics, settings, story or art direction
  on your own; put ideas to them as questions and record their decisions.

## Verifying work (Agent Kit)

Godot is at: `<PATH TO YOUR GODOT .EXE>` (it may not be on PATH; it has no console build on
Windows, so pass `--log-file <path>` and read the log).

A task is finished only when all of these are true, run from the project folder:

1. The project has been scanned, so every `class_name` exists:
   `"<godot>" --headless --path . --import`
2. Every script parses and every scene and resource loads:
   `"<godot>" --headless --path . -s res://addons/agent_kit/check_project.gd -- --quiet`
3. The tests pass, at fixed speed so a busy computer cannot change a result:
   `"<godot>" --headless --fixed-fps 120 --path . -s res://addons/agent_kit/run_tests.gd -- --quiet`
   Add `-- --only=<text>` to run matching files while iterating. Files that need a real
   network declare `const REAL_TIME := true` and run with `-- --real-time-only` and no
   `--fixed-fps`.
4. Anything visual was looked at: run the game (not headless) with
   `-- --screenshot=<out.png>` and open the PNG. The main scene has the kit's `screenshot.gd`
   node for this.
5. If a tuning setting was added or its description changed, the tuning sheet is current:
   `"<godot>" --headless --path . -s res://addons/agent_kit/tuning_sheet.gd -- --folders=<res://your/tuning/folder> --out=res://docs/TUNING.md`
   (a test can call it with `--check` to fail when the committed sheet is stale).

Report exactly what was verified and how, and what was not. Never say a change works
because the code looks right.

## Tests

- A test file is any `tests/**/test_*.gd` extending `res://tests/test_case.gd`, which extends
  `res://addons/agent_kit/test_case.gd`. Every method starting with `test_` is one test.
- A test fails on a failed `expect_*`, and on ANY error Godot reports while it runs: a script
  error always, a `push_error` unless the test called `expect_error("<part of the text>")`
  first. "Fails loudly" code is tested that way.
- Pure logic lives in `RefCounted` classes with no Node, scene, input or rendering, so it is
  testable headless. Tests that need the engine use `new_world_2d()` / `new_world_3d()` and
  `await wait_physics(n)` / `await wait_frames(n)`.
- Mark honestly missing things with `skip("<reason>")`. Never to hide a failure.

## Tuning settings

- Every number a designer might change is an `@export var` on a tuning `Resource` script, with
  a `.tres` under `<res://your/tuning/folder>`. Never a bare constant in gameplay code.
- Every exported setting has exactly one `##` line directly above it, in two parts:
  what you would notice, in plain words, then a colon and what it actually does (unit, what
  raising and lowering it does). The Inspector shows it as the tooltip; the tuning sheet is
  built from it. A test calls `expect_every_setting_described(script, true)` on each tuning
  script and `expect_tres_matches_script(tres, script)` on each file.
- The script defaults equal the shipped values. The editor only writes values that differ
  from the default, so a line missing from a `.tres` means the default.

## GDScript gotchas

- Write the type explicitly when a value comes from `a if cond else b`:
  `var x: float = a if cond else b`.
- An integer literal makes an `int`: write `2.0`, not `2`, for float settings.
- A freed object counts as `== null`; check `is_instance_valid(x)` alone.
- `class_name` names only exist after Godot has scanned the project: run `--import` first.
- A script run with `-s` is compiled before autoloads exist: wait one frame before touching
  them (the kit's runners already do).
- Edit `.tscn`, `.tres` and `project.godot` as text only while the editor is closed, or the
  editor saves its open copy over your change. Scripts, tests and docs are fine with it open.
- Pass a typed array (`var a: Array[Dictionary] = [...]`) to a parameter typed
  `Array[Dictionary]`; an untyped literal is a runtime error.

## Git

- One commit per logical piece, plain message: a short title, then what and why in a sentence
  or two. Commit only files you changed. Never push, rebase or rewrite history unless asked.
  Never commit `.godot/`.
