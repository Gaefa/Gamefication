extends Node
## Fixed-timestep simulation driver.
## Accumulates real time and fires ticks at TICK_INTERVAL rate.
## The actual tick logic lives in TickScheduler (created by GameOrchestrator).

const TICK_INTERVAL := 1.0  # seconds per game tick

var paused: bool = false
var speed_scale: float = 1.0  # 1x, 2x, 3x
var _accumulator: float = 0.0

## Set by GameOrchestrator after creating the scheduler.
var tick_callback: Callable = Callable()


func _physics_process(delta: float) -> void:
	if paused or tick_callback.is_null():
		return
	_accumulator += delta * speed_scale
	# Prevent spiral-of-death: cap at 5 ticks per frame
	var ticks_this_frame: int = 0
	while _accumulator >= TICK_INTERVAL and ticks_this_frame < 5:
		_accumulator -= TICK_INTERVAL
		ticks_this_frame += 1
		tick_callback.call()


func set_speed(multiplier: float) -> void:
	speed_scale = clampf(multiplier, 0.5, 5.0)

func toggle_pause() -> void:
	paused = not paused
