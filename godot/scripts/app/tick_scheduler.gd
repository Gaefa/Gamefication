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

	# Phase 1: Pre-tick -- decay buffs, decrement timers
	MaintenanceSystem.process_tick(state)

	# Phase 2: Infrastructure -- rebuild networks if dirty
	InfrastructureSystem.process_tick(state, _hex_grid, _transport_graph, _coverage_map, _spatial_index)

	# Phase 3: Economy -- production & consumption
	var economy: Dictionary = state.get("economy", {})
	EconomySystem.apply_production_tick(
		economy, state, _hex_grid, _spatial_index,
		_aura_cache, _road_network, _pipe_network
	)
	EconomySystem.update_caps(economy, _hex_grid, _spatial_index)

	# Phase 4+5+7: Progression (includes population, happiness, win checks, history)
	ProgressionSystem.process_tick(state, _hex_grid, _spatial_index, _aura_cache)

	# Phase 5: Pressure -- issue accumulation, phase changes
	if allow_issues:
		_phase_pressure(state)

	# Phase 6: Events -- timer countdown, event rolls
	EventSystem.process_tick(state)

	# Phase 8: Post-tick -- increment play_time
	var meta: Dictionary = state.get("meta", {})
	meta["play_time"] = float(meta.get("play_time", 0.0)) + 1.0
	meta["tick_count"] = int(meta.get("tick_count", 0)) + 1


# ------------------------------------------------------------------
# Pressure phase (inline, since pressure_director_system is Phase 9+)
# ------------------------------------------------------------------

func _phase_pressure(state: Dictionary) -> void:
	var pressure: Dictionary = state.get("pressure", {})

	# Count current issues
	var issue_count: int = 0
	for coord: Vector2i in _hex_grid.get_all_buildings():
		var bld_raw: Variant = _hex_grid.get_building(coord.x, coord.y)
		if bld_raw != null:
			var bld: Dictionary = bld_raw as Dictionary
			if bld.get("issue") != null:
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
