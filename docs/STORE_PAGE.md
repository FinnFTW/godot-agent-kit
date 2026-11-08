# Store page draft (itch.io and the Godot Asset Store)

Working title: **Agent Kit for Godot 4**. Decide the final name before publishing so the itch
page, the GitHub repo and the Asset Store entry match.

## Short description (itch tagline, 120 characters max)

Headless test runner, project check and tuning sheet for Godot 4, built so AI coding agents can prove their work.

## Long description

**Your agent says "done". Agent Kit checks.**

Five small GDScript tools that run from the command line with no editor open, so Claude
Code, Codex, Cursor or Copilot can verify a Godot project the way a careful human would:

- **A test runner that fails on any engine error.** A script crash, a `push_error`, a missing
  resource: all of them fail the test they happened in, with the file and line. Most runners
  count a crashed test as a pass because the function simply stops. Exit code 1 on failure,
  JUnit output for CI, `--fixed-fps` for deterministic suites.
- **A whole-project check.** Loads every script, scene and resource and reports the ones that
  do not parse or point at files that no longer exist. Run it after every batch of edits.
- **Tuning data lints.** Every `@export var` on your tuning resources must carry a one-line
  description the Inspector shows as a tooltip, and every `.tres` must only write real settings.
- **A tuning sheet generator.** One Markdown table of every tunable number, its default and
  what it does, generated from those same doc lines. `--check` fails CI when it is stale.
- **Screenshot on launch.** A node that saves a PNG after N frames and quits, so the agent can
  look at what it changed.

Plus a `CLAUDE.md` template that teaches your agent to run all of this before calling a task
finished.

**Tested on real projects, not a demo.** The runner executes 881 tests across 405 files on a
2D roguelike, and the project check runs clean on a 477-file 3D multiplayer game. Both are
built day to day with an AI agent using exactly this loop.

**Deliberately small.** No mocks, no editor dock, no GDExtension. If you want a full framework,
GUT and gdUnit4 are excellent and free. If you want five files that make a headless loop
trustworthy, this is it.

Pure GDScript. Godot 4.7+. MIT licensed. Source on GitHub.

**About AI use:** the code was written with Claude Code and tested by running it against the
projects above and reading the output. The author is a solo hobbyist developer; issues and
logs are welcome.

## Tags

godot, godot4, tools, development-tool, testing, ci, ai, claude, agent, gdscript

## Price

Free. "Pay what you want" on itch with $0 minimum. (This is the funnel for the paid Safe
Refactor addon; its page links back here.)

## Assets needed

- Cover 630x500: dark background, the five tool names as a terminal-style list with green
  PASS lines and one red FAIL line showing a caught crash.
- Screenshot 1: the test output with a crash caught ("crashed: Cannot call method 'get_name'
  on a null value [file:line]").
- Screenshot 2: `check_project.gd` reporting 39 broken sound resources on a project with its
  Audio folder removed.
- Screenshot 3: the generated TUNING.md rendered.
- GIF (30 to 60 s): an agent edits a script to introduce a crash, runs the suite, the crash is
  caught with the line number, the agent fixes it, green.

## Launch posts

- r/godot: "I built a small headless verification kit so Claude Code stops telling me my Godot
  game works when it doesn't" + the crash-caught screenshot. Lead with the problem, not the tool.
- Godot forum, Projects category: same, longer, with the CLAUDE.md template excerpt.
- itch devlog: the story of the 881-test project and what the runner caught in its first week.
- Mailing list: none yet; the itch page's "follow" and the GitHub repo are the list for now.
