class_name GameOrchestrator
## Factory that creates and wires all runtime objects.
## Entry point for new game / load game.

var hex_grid: HexGrid
var spatial: SpatialIndex
var coverage: CoverageMap
var aura_cache: AuraCache
var road_graph: TransportGraph
var road_network: RoadNetwork
var pipe_network: PipeNetwork
var resource_flow: ResourceFlow
var adjacency: AdjacencyCalculator
var synergy: SynergyResolver
var production_mult: ProductionMultiplier
var interactions: BuildingInteractions
var command_bus: CommandBus
var tick_scheduler: TickScheduler
var rng: SeededRNG

# Systems
var economy_sys: EconomySystem
var infrastructure_sys: InfrastructureSystem
var maintenance_sys: MaintenanceSystem
var issue_sys: IssueSystem
var progression_sys: ProgressionSystem
var event_sys: EventSystem
var pressure_sys: PressureSystem


func build() -> void:
	# Core data structures
	var map_radius: int = GameStateStore.world().get("map_radius", 30) as int
	hex_grid = HexGrid.new(map_radius)
	spatial = SpatialIndex.new()
	coverage = CoverageMap.new(spatial, hex_grid)
	aura_cache = AuraCache.new()
	road_graph = TransportGraph.new("road", spatial)
	road_network = RoadNetwork.new(spatial)
	pipe_network = PipeNetwork.new(coverage)
	resource_flow = ResourceFlow.new(coverage)

	# Building interactions
	adjacency = AdjacencyCalculator.new()
	synergy = SynergyResolver.new(adjacency, aura_cache)
	production_mult = ProductionMultiplier.new(synergy, road_network, coverage)
	interactions = BuildingInteractions.new(adjacency, aura_cache, synergy, production_mult)

	# RNG
	var seed_val: int = GameStateStore.save_meta().get("rng_seed", 12345) as int
	rng = SeededRNG.new(seed_val)

	# Systems
	economy_sys = EconomySystem.new(interactions, resource_flow)
	infrastructure_sys = InfrastructureSystem.new(coverage, road_graph, aura_cache)
	maintenance_sys = MaintenanceSystem.new()
	issue_sys = IssueSystem.new(rng)
	progression_sys = ProgressionSystem.new(aura_cache)
	event_sys = EventSystem.new(rng)
	pressure_sys = PressureSystem.new()

	# Tick scheduler
	tick_scheduler = TickScheduler.new(
		infrastructure_sys,
		economy_sys,
		maintenance_sys,
		issue_sys,
		progression_sys,
		event_sys,
		pressure_sys,
	)

	# Command bus
	command_bus = CommandBus.new()
	command_bus.set_context(_build_context())

	# Wire SimulationRunner
	SimulationRunner.tick_callback = tick_scheduler.run_tick


func new_game(seed_val: int = 0) -> void:
	if seed_val == 0:
		seed_val = randi()
	GameStateStore.reset()
	GameStateStore.save_meta().rng_seed = seed_val
	build()
	_generate_terrain()
	spatial.rebuild_from_state()
	EventBus.new_game_started.emit()


func load_game() -> void:
	build()
	spatial.rebuild_from_state()


func _build_context() -> Dictionary:
	return {
		"hex_grid": hex_grid,
		"spatial": spatial,
		"coverage": coverage,
		"road_graph": road_graph,
		"interactions": interactions,
		"event_system": event_sys,
	}


func _generate_terrain() -> void:
	var gen := TerrainGenerator.new(rng, hex_grid.radius)
	gen.generate()
