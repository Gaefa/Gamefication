## tick_scheduler.gd -- Orchestrates the 8-phase tick pipeline.
## Called by GameOrchestrator each simulation tick.  Each phase calls
## the corresponding system script with the necessary context objects.
class_name TickScheduler


## References to shared game objects (injected at init).
var _hex_grid: HexGrid = null
var _spatial_index: SpatialIndex = null
var _aura_cache: AuraCache = null
var _transport_graph: TransportGraph = null
var _road_network: RoadNetwork = null
var _pipe_network: PipeNetwork = null
var _coverage_map: CoverageMap = null


# ------------------------------------------------------------------
# Lifecycle
# ------------------------------------------------------------------

func _init(hex_grid: HexGrid, spatial_index: SpatialIndex,
		aura_cache: AuraCache, transport_graph: TransportGraph,
		road_network: RoadNetwork, pipe_network: PipeNetwork,
		coverage_map: CoverageMap) -> void:
	_hex_grid = hex_grid
	_spatial_index = spatial_index
	_aura_cache = aura_cache
	_transport_graph = transport_graph
	_road_network = road_network
	_pipe_network = pipe_network
	_coverage_map = coverage_map


# ------------------------------------------------------------------
# Run a single tick (8 phases)
# ------------------------------------------------------------------

func run_tick(allow_issues: bool = true) -> void:
	var state: Dictionary = GameStateStore.state
	if state.is_empty():
		return

	var economy: Dictionary = GameStateStore.get_economy()
	var population: Dictionary = GameStateStore.get_population()
	var progression: Dictionary = GameStateStore.get_progression()
	var pressure: Dictionary = GameStateStore.get_pressure()
	var events_state: Dictionary = GameStateStore.get_events()
	var meta: Dictionary = GameStateStore.get_save_meta()

	# Phase 1: Pre-tick -- decay buffs, decrement timers
	_phase_pre_tick(economy, events_state)

	# Phase 2: Infrastructure -- rebuild networks if dirty
	_phase_infrastructure()

	# Phase 3: Economy -- production & consumption
	_phase_economy(economy, state)

	# Phase 4: Citizen needs -- happiness, pop growth
	_phase_citizen_needs(population, economy)

	# Phase 5: Pressure -- issue accumulation, phase changes
	if allow_issues:
		_phase_pressure(pressure, population)

	# Phase 6: Events -- timer countdown, event rolls
	_phase_events(events_state, progression)

	# Phase 7: Progression -- level-up checks, win conditions
	_phase_progression(progression, economy, population)

	# Phase 8: Post-tick -- record history, increment play_time
	_phase_post_tick(meta)


# ------------------------------------------------------------------
# Phase implementations
# ------------------------------------------------------------------

func _phase_pre_tick(economy: Dictionary, events_state: Dictionary) -> void:
	MaintenanceSystem.decay_buffs(economy)
	events_state["timer"] = float(events_state.get("timer", 30.0)) - 1.0


func _phase_infrastructure() -> void:
	InfrastructureSystem.ensure_networks_fresh(_transport_graph, _hex_grid, _coverage_map)


func _phase_economy(economy: Dictionary, state: Dictionary) -> void:
	EconomySystem.apply_production_tick(
		economy, state, _hex_grid, _spatial_index,
		_aura_cache, _road_network, _pipe_network
	)
	EconomySystem.update_caps(economy, _hex_grid, _spatial_index)
	EconomySystem.compute_passive_stats(economy, state, _hex_grid, _spatial_index)


func _phase_citizen_needs(population: Dictionary, economy: Dictionary) -> void:
	ProgressionSystem.update_population(population, economy)
	ProgressionSystem.update_happiness(population, economy, _hex_grid, _spatial_index, _aura_cache)


func _phase_pressure(pressure: Dictionary, _population: Dictionary) -> void:
	# Count current issues
	var issue_count: int = 0
	for coord: Vector2i in _hex_grid.get_all_buildings():
		var bld: Dictionary = _hex_grid.get_building(coord.x, coord.y)
		if bld != null and bld.get("issue") != null:
			issue_count += 1
	pressure["issue_count"] = issue_count

	# Pressure index accumulation/decay
	var idx: float = float(pressure.get("index", 0.0))
	if issue_count > 3:
		idx += (issue_count - 3) * 0.5
	else:
		idx -= float(pressure.get("decay_rate", 0.01)) * 10.0
	idx = clampf(idx, 0.0, 100.0)
	pressure["index"] = idx

	# Phase transitions
	var old_phase: int = int(pressure.get("phase", 0))
	var new_phase: int = 0
	if idx >= 60.0:
		new_phase = 2  # crisis
	elif idx >= 30.0:
		new_phase = 1  # tension
	pressure["phase"] = new_phase

	if new_phase != old_phase:
		EventBus.pressure_phase_changed.emit(new_phase)


func _phase_events(events_state: Dictionary, progression: Dictionary) -> void:
	if events_state.get("active_event") != null:
		return
	if float(events_state.get("timer", 1.0)) > 0.0:
		return

	# Roll a new event
	EventSystem.roll_event(events_state, progression)

	# Reset timer
	events_state["timer"] = 30.0 + randf_range(-5.0, 10.0)


func _phase_progression(progression: Dictionary, economy: Dictionary,
		population: Dictionary) -> void:
	ProgressionSystem.check_level_up(progression, economy, population)
	ProgressionSystem.check_win_condition(progression, economy, population)
	ProgressionSystem.record_history(progression, economy, population)


func _phase_post_tick(meta: Dictionary) -> void:
	meta["play_time"] = float(meta.get("play_time", 0.0)) + 1.0
	meta["tick_count"] = int(meta.get("tick_count", 0)) + 1
