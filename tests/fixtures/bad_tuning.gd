extends Resource
## A tuning script that breaks the lint on purpose: one setting with no description, one
## whose tooltip puts a number before the colon. Used by tests/test_tuning.gd.

@export var undocumented: float = 1.0
## Runs at 60 frames: the target frame rate.
@export var fps: int = 60
