extends Node
## Fixed-timestep simulation driver.
## Accumulates real time and fires ticks at TICK_INTERVAL rate.
## The actual tick logic lives in TickScheduler (created by GameOrchestrator).
##
## v0.2: Добавлена фазовая система (День -> Вечер -> Утро) по TDD.md.

const TICK_INTERVAL := 1.0  # seconds per game tick

var paused: bool = false
var speed_scale: float = 1.0  # 1x, 2x, 3x
var _accumulator: float = 0.0

## Set by GameOrchestrator after creating the scheduler.
var tick_callback: Callable = Callable()

# --- Фазовая система ---
enum Phase { DAY, EVENING, MORNING }
var current_phase: Phase = Phase.DAY
var day_duration: float = 300.0  # секунд реального времени на один игровой день (5 мин)
var day_timer: float = 300.0
## 1-based game day counter. Advanced at the start of each new day.
## SeasonSystem reads this to know when a day has elapsed.
## Re-synced from GameStateStore.climate().total_day by SeasonSystem.initialize().
var day_count: int = 1

func _physics_process(delta: float) -> void:
	if paused or tick_callback.is_null():
		return
	
	# Фазовый таймер (только в фазе ДНЯ)
	if current_phase == Phase.DAY:
		day_timer -= delta * speed_scale
		EventBus.day_timer_updated.emit(day_timer)
		if day_timer <= 0.0:
			_transition_to_evening()
			return
	
	_accumulator += delta * speed_scale
	# Prevent spiral-of-death: cap at 5 ticks per frame
	var ticks_this_frame: int = 0
	while _accumulator >= TICK_INTERVAL and ticks_this_frame < 5:
		_accumulator -= TICK_INTERVAL
		ticks_this_frame += 1
		tick_callback.call()


func _transition_to_evening() -> void:
	current_phase = Phase.EVENING
	paused = true
	EventBus.phase_changed.emit("evening")
	# EventManager слушает этот сигнал и отправляет pending_events в DeskUI


func transition_to_morning() -> void:
	## Вызывается из DeskUI когда игрок закончил разбирать почту.
	current_phase = Phase.MORNING
	EventBus.phase_changed.emit("morning")
	# Применяем последствия (будущее расширение)
	# Сразу переходим в новый день
	_start_new_day()


func _start_new_day() -> void:
	current_phase = Phase.DAY
	day_timer = day_duration
	paused = false
	day_count += 1
	EventBus.phase_changed.emit("day")


func resume_after_load() -> void:
	## A loaded game resumes in the DAY phase, not stuck in a paused/evening state.
	## SeasonSystem.initialize() already re-synced day_count from climate.total_day.
	current_phase = Phase.DAY
	day_timer = day_duration
	_accumulator = 0.0
	paused = false


func set_speed(multiplier: float) -> void:
	speed_scale = clampf(multiplier, 0.5, 5.0)

func toggle_pause() -> void:
	# Не даём снять паузу вечером — только через DeskUI
	if current_phase == Phase.EVENING:
		return
	paused = not paused
