## simulation_runner.gd -- Runs the tick pipeline each TICK_INTERVAL seconds.
## Individual system scripts are called in a fixed order.  Placeholder
## calls are left where future system scripts will be wired in.
class_name SimulationRunnerClass
extends Node

# ---- Public state ----
var tick_count: int = 0
var is_paused: bool = false

# ---- Internal ----
var _accumulator: float = 0.0
const TICK_INTERVAL: float = 1.0

# ------------------------------------------------------------------
# Lifecycle
# ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not GameStateStore.is_playing:
		return
	if is_paused:
		return

	_accumulator += delta
	while _accumulator >= TICK_INTERVAL:
		run_single_tick()
		tick_count += 1
		_accumulator -= TICK_INTERVAL


# ------------------------------------------------------------------
# Single tick
# ------------------------------------------------------------------

func run_single_tick(allow_issues: bool = true) -> void:
	var st: Dictionary = GameStateStore.state
	if st.is_empty():
		return

	var economy: Dictionary = GameStateStore.get_economy()
	var population: Dictionary = GameStateStore.get_population()
	var progression: Dictionary = GameStateStore.get_progression()
	var pressure: Dictionary = GameStateStore.get_pressure()
	var events_state: Dictionary = GameStateStore.get_events()
	var meta: Dictionary = GameStateStore.get_meta()

	# -------------------------------------------------------
	# 1. Pre-tick: decay buffs, decrement timers
	# -------------------------------------------------------
	_pre_tick(economy, events_state)

	# -------------------------------------------------------
	# 2. Economy system: production & consumption
	# -------------------------------------------------------
	_tick_economy(economy)

	# -------------------------------------------------------
	# 3. Infrastructure system: road/water/power networks
	# -------------------------------------------------------
	_tick_infrastructure()

	# -------------------------------------------------------
	# 4. Citizen needs: happiness, population growth
	# -------------------------------------------------------
	_tick_citizen_needs(population, economy)

	# -------------------------------------------------------
	# 5. Pressure system: issue accumulation, phase changes
	# -------------------------------------------------------
	if allow_issues:
		_tick_pressure(pressure, population)

	# -------------------------------------------------------
	# 6. Events system: timer countdown, event rolls
	# -------------------------------------------------------
	_tick_events(events_state, progression)

	# -------------------------------------------------------
	# 7. Progression system: level-up checks
	# -------------------------------------------------------
	_tick_progression(progression, economy, population)

	# -------------------------------------------------------
	# 8. Post-tick: record history, increment play_time
	# -------------------------------------------------------
	_post_tick(meta)


# ------------------------------------------------------------------
# Offline ticks -- run N ticks quickly (no events / issues)
# ------------------------------------------------------------------

func run_offline_ticks(count: int) -> void:
	if count <= 0:
		return
	# Cap offline ticks to prevent extreme lag
	var capped: int = mini(count, 14400)
	print("SimulationRunner: running %d offline ticks." % capped)
	for i: int in range(capped):
		run_single_tick(false)   # no random issues during offline catch-up
		tick_count += 1
	print("SimulationRunner: offline ticks complete.")


# ------------------------------------------------------------------
# Pause / unpause
# ------------------------------------------------------------------

func pause() -> void:
	is_paused = true


func unpause() -> void:
	is_paused = false
	_accumulator = 0.0


func toggle_pause() -> bool:
	if is_paused:
		unpause()
	else:
		pause()
	return is_paused


# ==================================================================
# Private tick steps (placeholders wired to future system scripts)
# ==================================================================

func _pre_tick(economy: Dictionary, events_state: Dictionary) -> void:
	# Decay active buffs
	var buffs: Array = economy.get("buffs", [])
	var i: int = buffs.size() - 1
	while i >= 0:
		var buff: Dictionary = buffs[i]
		buff["remaining"] = float(buff.get("remaining", 0)) - TICK_INTERVAL
		if buff["remaining"] <= 0.0:
			buffs.remove_at(i)
		i -= 1

	# Decrement event timer
	events_state["timer"] = float(events_state.get("timer", 30.0)) - TICK_INTERVAL


func _tick_economy(_economy: Dictionary) -> void:
	# TODO: wire EconomySystem.process_tick(economy, world)
	# This will iterate all buildings, compute production/consumption,
	# apply terrain bonuses, synergy modifiers, buff multipliers,
	# and update resource values clamped to caps.
	pass


func _tick_infrastructure() -> void:
	# TODO: wire InfrastructureSystem.process_tick(world)
	# This will recompute road connectivity, water coverage,
	# power coverage graphs and apply efficiency penalties.
	pass


func _tick_citizen_needs(_population: Dictionary, _economy: Dictionary) -> void:
	# TODO: wire CitizenNeedsSystem.process_tick(population, economy, world)
	# This will calculate happiness from coverage, resource satisfaction,
	# buffs, and events.  Population growth/decline follows happiness.
	pass


func _tick_pressure(_pressure: Dictionary, _population: Dictionary) -> void:
	# TODO: wire PressureSystem.process_tick(pressure, population, world)
	# This will accumulate pressure from unresolved issues, lack of
	# services, overcrowding.  Phase thresholds at 30 / 60.
	pass


func _tick_events(events_state: Dictionary, _progression: Dictionary) -> void:
	# Check if timer expired and no active event
	if events_state.get("active_event") != null:
		return
	if float(events_state.get("timer", 1.0)) > 0.0:
		return
	# TODO: wire EventsSystem.roll_event(events_state, progression)
	# This will pick a random event matching city_level and pressure_phase,
	# set it as active_event, emit EventBus.event_fired, and reset timer.

	# Reset timer for next roll even if no system is wired yet
	events_state["timer"] = 30.0 + randf_range(-5.0, 10.0)


func _tick_progression(_progression: Dictionary, _economy: Dictionary,
		_population: Dictionary) -> void:
	# TODO: wire ProgressionSystem.process_tick(progression, economy, population)
	# This will check city_level requirements from ContentDB.get_city_level()
	# and emit city_level_changed when thresholds are met.
	pass


func _post_tick(meta: Dictionary) -> void:
	meta["play_time"] = float(meta.get("play_time", 0.0)) + TICK_INTERVAL
	meta["tick_count"] = int(meta.get("tick_count", 0)) + 1
	EventBus.tick_completed.emit(tick_count)
