class_name PlaceBuildingCommand extends CommandBase
## Places a building on the hex grid.

var coord: Vector2i
var type_id: String


func _init(p_coord: Vector2i, p_type_id: String) -> void:
	coord = p_coord
	type_id = p_type_id


func execute(ctx: Dictionary) -> void:
	var hex_grid: HexGrid = ctx.hex_grid as HexGrid
	var spatial: SpatialIndex = ctx.spatial as SpatialIndex

	# Validate
	var def: Dictionary = ContentDB.get_building_def(type_id)
	if def.is_empty():
		message = "Unknown building: %s" % type_id
		return

	if not hex_grid.can_build_at(coord):
		message = "Cannot build here"
		return

	# Check unlock level
	var req_level: int = def.get("unlock_level", 1) as int
	var city_level: int = GameStateStore.progression().city_level as int
	if city_level < req_level:
		message = "Requires city level %d" % req_level
		return

	# Check cost
	var build_cost: Dictionary = def.get("build_cost", {})
	if not GameStateStore.can_afford(build_cost):
		message = "Not enough resources"
		return

	# Spend & place
	GameStateStore.spend(build_cost)
	var bld: Dictionary = {
		"type": type_id,
		"level": 0,
		"damaged": false,
		"has_issue": false,
	}
	GameStateStore.set_building(coord, bld)
	spatial.add(coord, type_id)

	# Invalidate caches
	var interactions: BuildingInteractions = ctx.get("interactions") as BuildingInteractions
	if interactions:
		interactions.invalidate_caches()
	var coverage: CoverageMap = ctx.get("coverage") as CoverageMap
	if coverage:
		coverage.invalidate()
	var road_graph: TransportGraph = ctx.get("road_graph") as TransportGraph
	if road_graph:
		road_graph.invalidate()

	success = true
	message = "Built %s" % def.get("label", type_id)
	EventBus.building_placed.emit(coord, type_id)
