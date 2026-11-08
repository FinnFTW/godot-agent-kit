class_name DemoTuning
extends Resource
## A tuning file as the kit expects them: every exported setting has one "##" line above it
## in two parts, what you would notice then a colon and what it actually does. The Inspector
## shows the line as the tooltip; tuning_sheet.gd collects them into docs/TUNING.md.

@export_group("Movement")
## How fast the player runs: metres per second of top speed on flat ground.
@export var run_speed: float = 6.0
## How high the player jumps: the upward speed given at take-off, in metres per second.
@export var jump_speed: float = 9.0

@export_group("Feel")
## How long the screen shakes after a hit: seconds, fading out linearly.
@export var shake_time: float = 0.25
## Whether slow motion plays on a big hit: on or off.
@export var slow_motion: bool = true
## The tint of the screen while slowed: the colour mixed over the view, alpha is strength.
@export var slow_tint: Color = Color(0.2, 0.3, 0.8, 0.3)
