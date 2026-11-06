class_name GameOrchestrator
## Factory that creates and wires all runtime objects.
## Entry point for new game / load game.

var hex_grid: HexGrid
var spatial: SpatialIndex
var coverage: CoverageMap
var aura_cache: AuraCache
var road_network: RoadNetwork
var resource_flow: ResourceFlow
var adjacency: AdjacencyCalculator
var synergy: SynergyResolver
var production_mult: ProductionMultiplier
var interactions: BuildingInteractions
var command_bus: CommandBus
var tick_scheduler: TickScheduler
var rng: SeededRNG

# Systems
var season_sys: SeasonSystem
var power_sys: PowerSystem
var economy_sys: EconomySystem
var infrastructure_sys: InfrastructureSystem
var maintenance_sys: MaintenanceSystem
var issue_sys: IssueSystem
var progression_sys: ProgressionSystem
var pressure_sys: PressureSystem


func build() -> void:
	# Core data structures
	var map_radius: int = GameStateStore.world().get("map_radius", 30) as int
	hex_grid = HexGrid.new(map_radius)
	spatial = SpatialIndex.new()
	coverage = CoverageMap.new(spatial, hex_grid)
	aura_cache = AuraCache.new()
	road_network = RoadNetwork.new(spatial)
	resource_flow = ResourceFlow.new(coverage)

	# Building interactions
	adjacency = AdjacencyCalculator.new()
	synergy = SynergyResolver.new(adjacency, aura_cache)
	production_mult = ProductionMultiplier.new(synergy, road_network, coverage)
	interactions = BuildingInteractions.new(adjacency, aura_cache, synergy, production_mult)

	# RNG
	var seed_val: int = GameStateStore.save_meta().get("rng_seed", 12345) as int
	rng = SeededRNG.new(seed_val)
	# A loaded game continues the exact random sequence it was saved with (tick-for-tick load).
	if GameStateStore.save_meta().has("rng_state"):
		rng.set_state(GameStateStore.save_meta().get("rng_state", 0) as int)

	# Systems
	season_sys = SeasonSystem.new()
	power_sys = PowerSystem.new()
	economy_sys = EconomySystem.new(interactions, resource_flow)
	infrastructure_sys = InfrastructureSystem.new(coverage, aura_cache)
	maintenance_sys = MaintenanceSystem.new()
	issue_sys = IssueSystem.new(rng)
	progression_sys = ProgressionSystem.new(aura_cache, coverage)
	pressure_sys = PressureSystem.new()

	# Tick scheduler
	tick_scheduler = TickScheduler.new(
		season_sys,
		power_sys,
		infrastructure_sys,
		economy_sys,
		maintenance_sys,
		issue_sys,
		progression_sys,
		pressure_sys,
	)

	# Command bus
	command_bus = CommandBus.new()
	command_bus.set_context(_build_context())

	# Wire SimulationRunner
	SimulationRunner.tick_callback = tick_scheduler.run_tick


func new_game(seed_val: int = 0, profile_id: String = "appointed_administrator", legacy_id: String = "", chapter_id: String = "") -> void:
	if seed_val == 0:
		seed_val = randi()
	# No chapter named: the campaign's first one (the title screen always names one).
	ContentDB.set_chapter(chapter_id if chapter_id != "" else ContentDB.default_chapter())
	EventBus.run_reset.emit()
	GameStateStore.reset(profile_id)
	GameStateStore.save_meta().rng_seed = seed_val
	GameStateStore.save_meta().chapter_id = ContentDB.active_chapter
	build()
	_generate_terrain()
	GameStateStore.save_meta().rng_state = rng.get_state()
	_bootstrap_campaign_hub()
	_apply_legacy(legacy_id)
	spatial.rebuild_from_state()
	coverage.invalidate()
	aura_cache.invalidate()
	season_sys.initialize()
	infrastructure_sys.process_tick()
	_apply_legacy_resources(legacy_id)
	EventBus.new_game_started.emit()


func load_game() -> void:
	# Rebuild the runtime from already-loaded state. Mirrors new_game() EXCEPT we
	# do NOT regenerate terrain (it is serialized in the save) and do NOT bootstrap
	# the starter layout. State must already be in GameStateStore (SaveService loads
	# it before emitting game_loaded), since build() reads world().map_radius.
	EventBus.run_reset.emit()
	build()
	spatial.rebuild_from_state()
	coverage.invalidate()
	aura_cache.invalidate()
	season_sys.initialize()
	infrastructure_sys.process_tick()


func _build_context() -> Dictionary:
	return {
		"hex_grid": hex_grid,
		"spatial": spatial,
		"coverage": coverage,
		"interactions": interactions,
	}


func _generate_terrain() -> void:
	var gen := TerrainGenerator.new(rng, hex_grid.radius)
	gen.generate()


func _bootstrap_campaign_hub() -> void:
	# The starter layout is the chapter's (chapter.json start_layout); Rust Pit's is the
	# post, the cistern, the store, a pump, a shelter, a plot, a panel and the Company's traces.
	var chapter: Dictionary = ContentDB.get_chapter_def()
	for entry: Variant in chapter.get("start_layout", []) as Array:
		var cell: Array = (entry as Dictionary).get("coord", [0, 0]) as Array
		var type_id: String = (entry as Dictionary).get("type", "") as String
		if type_id == "":
			continue
		GameStateStore.set_building(Vector2i(cell[0] as int, cell[1] as int), {
			"type": type_id,
			"level": 0,
			"damaged": false,
			"has_issue": false,
		})
	if chapter.get("company_traces", false) as bool:
		_bootstrap_company_traces()


## What the previous administrator left (start_legacies.json): the same map, a different
## first ten minutes. Extra buildings, wrecked ones, a stocked or emptied store, a lower
## patron trust, and flags the Desk cards key on. An empty id is the plain start.
func _apply_legacy(legacy_id: String) -> void:
	GameStateStore.save_meta().legacy_id = legacy_id
	GameStateStore.mandate()["legacy_id"] = legacy_id
	var legacy: Dictionary = ContentDB.get_start_legacy_def(legacy_id)
	if legacy.is_empty():
		return
	for entry: Variant in legacy.get("buildings", []) as Array:
		var cell: Array = (entry as Dictionary).get("coord", [0, 0]) as Array
		GameStateStore.set_building(Vector2i(cell[0] as int, cell[1] as int), {
			"type": (entry as Dictionary).get("type", "") as String, "level": 0, "damaged": false, "has_issue": false,
		})
	for type_id: Variant in legacy.get("damaged", []) as Array:
		for coord: Vector2i in GameStateStore.get_all_building_coords():
			var bld: Dictionary = GameStateStore.get_building(coord)
			if bld.get("type", "") == type_id and not (bld.get("damaged", false) as bool):
				bld["damaged"] = true
				GameStateStore.set_building(coord, bld)
				break
	var mandate_state: Dictionary = GameStateStore.mandate()
	var overrides: Dictionary = legacy.get("mandate", {}) as Dictionary
	for key: String in overrides:
		mandate_state[key] = overrides[key]
	if legacy.has("residents"):
		# People who were here before the pump broke: they leave over days unless it is fixed.
		GameStateStore.population()["residents"] = float(legacy.get("residents", 0) as int)
		GameStateStore.population()["total"] = legacy.get("residents", 0) as int
	var flags: Dictionary = mandate_state.get("flags", {}) as Dictionary
	for flag: Variant in legacy.get("flags", []) as Array:
		flags[flag as String] = true
	mandate_state["flags"] = flags


## The legacy's stores go in once the infrastructure tick has set the caps: a full cistern
## is 750 only after the cistern has told the store how much it holds.
func _apply_legacy_resources(legacy_id: String) -> void:
	var resources: Dictionary = ContentDB.get_start_legacy_def(legacy_id).get("resources", {}) as Dictionary
	for res_id: String in resources:
		GameStateStore.set_resource(res_id, resources[res_id] as float)


## The district is not a clean building site (GDD §3.1): the Company's dead pipeline runs
## out from the tower, and its ruined depots stand where the pipes used to feed. Fixed
## layout — no RNG, so the balance sims and the RNG save state are untouched.
func _bootstrap_company_traces() -> void:
	var pipes: Array = [
		[[2, 1], [3, 1], [4, 1], [5, 0], [6, 0], [7, -1], [8, -1]],
		[[2, 1], [2, 2], [1, 3], [1, 4], [0, 5], [0, 6]],
		[[2, 1], [3, 0], [4, -1], [4, -2], [5, -3], [5, -4], [6, -5]],
	]
	GameStateStore.world()["decor"] = { "pipes": pipes, "props": [] }
	for cell: Array in [[8, -1], [0, 6], [6, -5], [-4, 2], [-3, -2]]:
		var coord := Vector2i(cell[0] as int, cell[1] as int)
		if GameStateStore.has_building(coord):
			continue
		var terrain_def: Dictionary = ContentDB.get_terrain_def(hex_grid.get_terrain_at(coord))
		if not (terrain_def.get("buildable", true) as bool):
			continue
		GameStateStore.set_building(coord, {
			"type": "bld_company_ruin",
			"level": 0,
			"damaged": false,
			"has_issue": false,
		})
	# Decorative only: these cells stay available to the placement rules. No RNG calls.
	var props: Array = GameStateStore.world().decor.props
	for entry: Array in [
		[3, 1, "prop_pipe_straight"], [4, 1, "prop_pipe_bend"], [5, 0, "prop_pipe_broken"],
		[1, 3, "prop_pipe_straight"], [1, 4, "prop_pipe_bend"], [0, 5, "prop_pipe_broken"],
		[4, -1, "prop_pipe_bend"], [5, -3, "prop_pipe_straight"], [5, -4, "prop_pipe_broken"],
		[-3, 3, "prop_sign_company"], [1, 1, "prop_barrels"], [-3, 1, "prop_leaflets"],
		[0, 3, "prop_dry_well"], [-3, 0, "prop_tarp_tent"], [-2, -1, "prop_fence"],
	]:
		if not GameStateStore.has_building(Vector2i(entry[0], entry[1])):
			props.append({"q": entry[0], "r": entry[1], "id": entry[2]})
	# Scatter scrap beside depots only where a ruin was actually placed.
	for cell: Array in [[8, -1], [0, 6], [6, -5], [-4, 2], [-3, -2]]:
		var ruin := Vector2i(cell[0], cell[1])
		var beside := ruin + Vector2i(0, 1)
		if GameStateStore.get_building(ruin).get("type", "") == "bld_company_ruin" and not GameStateStore.has_building(beside):
			props.append({"q": beside.x, "r": beside.y, "id": "prop_debris"})
