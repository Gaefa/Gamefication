class_name BulldozeCommand extends CommandBase
## Removes a building, refunding 10% of build cost.

var coord: Vector2i


func _init(p_coord: Vector2i) -> void:
	coord = p_coord


func execute(ctx: Dictionary) -> void:
	if not GameStateStore.has_building(coord):
		message = "Nothing to bulldoze"
		return

	var bld: Dictionary = GameStateStore.get_building(coord)
	var type_id: String = bld.get("type", "") as String
	var def: Dictionary = ContentDB.get_building_def(type_id)
	var spatial: SpatialIndex = ctx.spatial as SpatialIndex

	# Refund 10%
	var build_cost: Dictionary = def.get("build_cost", {})
	for res_id: String in build_cost:
		var refund: float = (build_cost[res_id] as float) * 0.1
		GameStateStore.add_resource(res_id, refund)

	GameStateStore.remove_building(coord)
	spatial.remove(coord, type_id)

	# Invalidate
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
	message = "Bulldozed %s" % def.get("label", type_id)
	EventBus.building_removed.emit(coord, type_id)
