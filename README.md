# Agent Kit for Godot 4

Headless verification for Godot projects built with AI coding agents (Claude Code, Codex,
Cursor, Copilot, or a human at a terminal). Five small tools, all GDScript, all run from the
command line with no editor open, so an agent can prove its work instead of saying "done":

| Tool | What it does | Run |
|---|---|---|
| `run_tests.gd` | Test runner. Fails a test on any engine error, not just failed assertions: a script crash, a `push_error`, a missing resource. Exit code 1 on failure. JUnit output for CI. | `godot --headless --fixed-fps 120 --path . -s res://addons/agent_kit/run_tests.gd` |
| `check_project.gd` | Loads every script, scene and resource in the project and reports the ones that do not parse or point at missing files. | `godot --headless --path . -s res://addons/agent_kit/check_project.gd` |
| `test_case.gd` | The base class for tests: `expect_*` helpers, `expect_error()` for code that must fail loudly, `skip()`, 2D/3D worlds that clean themselves up, `await wait_physics(n)`, and lints for tuning data. | `extends "res://addons/agent_kit/test_case.gd"` |
| `tuning_sheet.gd` | Turns the `##` doc line above every `@export var` into one Markdown sheet of every tunable number, its default and what it does. `--check` fails CI when the sheet is stale. | `godot --headless --path . -s res://addons/agent_kit/tuning_sheet.gd -- --folders=res://data/tuning` |
| `screenshot.gd` | A node that saves a PNG of the game after N frames and quits, so an agent can look at what it changed. | `godot --path . -- --screenshot=out.png` |

Tested on Godot 4.7.2. Used daily on two real projects: one with 881 tests, 405 files and 213
tuning settings; one 3D multiplayer game with 91 test files.

## Why

Agents are good at writing GDScript and bad at knowing whether it works. The Godot editor
reports errors in a panel no agent reads. A test that calls a method on `null` just stops,
and most runners count that as a pass. A renamed resource breaks a scene nobody opened.
Agent Kit makes each of those a failing command with a non-zero exit code and a readable
message, which is the only thing an agent reliably acts on.

The kit is deliberately small. If you want a full framework with mocks, parameterised tests
and an editor dock, use [GUT](https://github.com/bitwes/Gut) or
[gdUnit4](https://github.com/MikeSchulze/gdUnit4). If you want five files that make a
headless loop trustworthy, this is it.

## Install

1. Copy `addons/agent_kit/` into your project's `addons/` folder (or install from the Godot
   Asset Store / itch.io and let the editor do it).
2. Optional: enable the plugin in Project Settings > Plugins. It only adds two entries to
   Project > Tools (run tests, check project). Everything works without it.
3. Create `tests/test_case.gd`:
   ```gdscript
   extends "res://addons/agent_kit/test_case.gd"
   ## This project's test base: the kit's, plus helpers your tests share.
   ```
4. Copy `templates/CLAUDE.md` to your project root and fill in the two placeholders. It tells
   your agent how to verify its work with these tools.

## Writing a test

Any `tests/**/test_*.gd` that extends your `tests/test_case.gd`. Every method starting with
`test_` is one test.

```gdscript
extends "res://tests/test_case.gd"

func test_score_adds_up() -> void:
    var s := Score.new()
    s.add(3)
    s.add(4)
    expect_eq(s.total, 7, "two adds")

func test_negative_is_refused_loudly() -> void:
    expect_error("negative")        # the code under test must push_error containing this
    Score.new().add(-1)

func test_player_lands() -> void:
    var world := new_world_2d()     # freed automatically when the test ends
    var p := Player.new()
    world.add_child(p)
    await wait_physics(30)
    expect_true(p.is_on_floor(), "on the floor after half a second")

func test_level_three_boss() -> void:
    skip("level three is not built yet")
```

Run with `--fixed-fps 120` and every frame is exactly one physics tick: the suite runs as fast
as the machine allows and a busy computer cannot change a result. Files that need real time
(a real network connection) declare `const REAL_TIME := true`; they are skipped at fixed
speed and run with `-- --real-time-only` and no `--fixed-fps`.

Runner options after `--`: `--only=<text>`, `--dir=<res path>` (default `res://tests`),
`--real-time-only`, `--junit=<path>`, `--quiet`.

## Tuning data lints

If your tunable numbers live on `Resource` scripts as `@export var`s, two helpers keep them
honest:

```gdscript
func test_movement_tuning_is_documented() -> void:
    expect_every_setting_described("res://data/tuning/movement_tuning.gd", true)
    expect_tres_matches_script("res://data/tuning/movement.tres", "res://data/tuning/movement_tuning.gd")
```

The first fails when any exported setting lacks a `##` line above it. With `strict = true`
it also demands the two-part shape that reads well to a non-programmer, which the Inspector
shows as the tooltip and `tuning_sheet.gd` turns into a table:

```gdscript
## How fast the player runs: metres per second of top speed on flat ground.
@export var run_speed: float = 6.0
```

The second fails when a `.tres` writes a value that is not a setting of its script (a typo,
or a setting that was renamed). See `docs/TUNING.md` in this repo for what the sheet looks
like; it is generated from `demo/tuning/`.

## Headless on Windows

The Windows Godot build has no console, so nothing prints to the terminal. Pass
`--log-file <path>` and read the file. `run_tests.bat` in this repo shows the pattern,
including the `--import` step that must run once so `class_name`s exist.

## This repository

The repo is itself a Godot project: the addon in `addons/agent_kit/`, its own tests in
`tests/`, a demo scene and tuning file in `demo/`, and `demo/failing_suite/`, a suite that
must fail (run it with `-- --dir=res://demo/failing_suite` to see a crash, an unexpected
error and a plain failure reported).

## Honesty note

Written with Claude Code, tested by running it against real projects and reading the
output. If something is wrong, open an issue with the log file and the Godot version.

MIT licensed.
