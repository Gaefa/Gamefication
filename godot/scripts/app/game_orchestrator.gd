## game_orchestrator.gd -- Top-level coordinator that owns all runtime objects.
## Creates HexGrid, SpatialIndex, AuraCache, networks, CommandBus, TickScheduler.
## Wires everything together and provides the public API for starting/loading games.
class_name GameOrchestrator
extends Node


# ---- Owned runtime objects ----
var hex_grid: HexGrid = null
var spatial_index: SpatialIndex = null
var aura_cache: AuraCache = null
var transport_graph: TransportGraph = null
var road_network: RoadNetwork = null
var pipe_network: PipeNetwork = null
var coverage_map: CoverageMap = null
var command_bus: CommandBus = null
var tick_scheduler: TickScheduler = null

## Tick counter (mirrors meta.tick_count but tracked locally too).
var tick_count: int = 0

## Pause state.
var is_paused: bool = false

## Accumulator for fixed-step ticks.
var _accumulator: float = 0.0
const TICK_INTERVAL: float = 1.0


# ------------------------------------------------------------------
# Lifecycle
# ------------------------------------------------------------------

func _ready() -> void:
	# Connect to EventBus for network invalidation
	EventBus.game_started.connect(_on_game_started)
	EventBus.game_loaded.connect(_on_game_loaded)
	EventBus.building_placed.connect(_on_building_changed)
	EventBus.building_removed.connect(_on_building_removed)
	EventBus.network_invalidated.connect(_on_network_invalidated)


func _physics_process(delta: float) -> void:
	if not GameStateStore.is_playing:
		return
	if is_paused:
		return
	if tick_scheduler == null:
		return

	_accumulator += delta
	while _accumulator >= TICK_INTERVAL:
		tick_scheduler.run_tick(true)
		tick_count += 1
		_accumulator -= TICK_INTERVAL
		EventBus.tick_completed.emit(tick_count)


# ------------------------------------------------------------------
# Public API
# ------------------------------------------------------------------

## Start a new game with optional seed.
func start_new_game(seed_value: int = 0) -> void:
	GameStateStore.new_game(seed_value)
	_initialize_runtime()

	# Generate terrain
	var world: Dictionary = GameStateStore.get_world()
	var actual_seed: int = int(world.get("seed", randi()))
	var tg := TerrainGenerator.new()
	tg.generate(hex_grid, actual_seed)

	# Sync terrain back to state (store the seed; terrain is in HexGrid)
	world["terrain_generated"] = true


## Load a game from the given state dict.
func load_game(state: Dictionary) -> void:
	GameStateStore.state = state
	GameStateStore.is_playing = true
	_initialize_runtime()
	_rebuild_from_state()


## Execute a command through the CommandBus.
func execute_command(cmd: CommandBase) -> bool:
	if command_bus == null:
		push_warning("GameOrchestrator: no active game -- cannot execute command.")
		return false
	return command_bus.execute(cmd)


## Pause the simulation.
func pause() -> void:
	is_paused = true


## Unpause the simulation.
func unpause() -> void:
	is_paused = false
	_accumulator = 0.0


## Toggle pause.
func toggle_pause() -> bool:
	if is_paused:
		unpause()
	else:
		pause()
	return is_paused


## Run N offline ticks (e.g., after loading a save with elapsed time).
func run_offline_ticks(count: int) -> void:
	if tick_scheduler == null:
		return
	var capped: int = mini(count, 14400)
	for i: int in range(capped):
		tick_scheduler.run_tick(false)
		tick_count += 1


# ------------------------------------------------------------------
# Internal initialization
# ------------------------------------------------------------------

func _initialize_runtime() -> void:
	var world: Dictionary = GameStateStore.get_world()
	var grid_size: int = int(world.get("grid_size", 64))

	# Create core data structures
	hex_grid = HexGrid.new(grid_size)
	spatial_index = SpatialIndex.new()
	aura_cache = AuraCache.new()
	transport_graph = TransportGraph.new()
	road_network = RoadNetwork.new()
	pipe_network = PipeNetwork.new()
	coverage_map = CoverageMap.new()

	# Create app-layer coordinators
	command_bus = CommandBus.new(hex_grid, spatial_index, aura_cache, transport_graph)
	tick_scheduler = TickScheduler.new(
		hex_grid, spatial_index, aura_cache, transport_graph,
		road_network, pipe_network, coverage_map
	)

	tick_count = int(GameStateStore.get_save_meta().get("tick_count", 0))
	_accumulator = 0.0


## Rebuild HexGrid and SpatialIndex from existing state buildings dict.
func _rebuild_from_state() -> void:
	var world: Dictionary = GameStateStore.get_world()
	var buildings_dict: Dictionary = world.get("buildings", {})

	# Populate terrain if stored (otherwise regenerate)
	if not world.get("terrain_generated", false):
		var actual_seed: int = int(world.get("seed", 0))
		if actual_seed != 0:
			var tg := TerrainGenerator.new()
			tg.generate(hex_grid, actual_seed)
			world["terrain_generated"] = true

	# Populate buildings
	for key: String in buildings_dict:
		var parts: PackedStringArray = key.split(",")
		if parts.size() < 2:
			continue
		var q: int = int(parts[0])
		var r: int = int(parts[1])
		var bld_data: Dictionary = buildings_dict[key]
		hex_grid.set_building(q, r, bld_data)
		spatial_index.add(Vector2i(q, r), bld_data.get("type", ""))

	# Rebuild transport networks
	transport_graph.rebuild(hex_grid)
	aura_cache.invalidate_all()


# ------------------------------------------------------------------
# Signal handlers
# ------------------------------------------------------------------

func _on_game_started() -> void:
	# Runtime is already initialized by start_new_game/load_game
	pass


func _on_game_loaded(slot: int) -> void:
	# Re-initialize from the loaded state
	_initialize_runtime()
	_rebuild_from_state()


func _on_building_changed(coord: Vector2i, _type_id: String) -> void:
	transport_graph.invalidate()


func _on_building_removed(coord: Vector2i) -> void:
	transport_graph.invalidate()


func _on_network_invalidated() -> void:
	transport_graph.invalidate()
