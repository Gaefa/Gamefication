class_name PlaceBuildingCommand extends CommandBase
## Places a building on the hex grid.

const PlacementRulesRef := preload("res://scripts/core/buildings/placement_rules.gd")

var coord: Vector2i
var type_id: String


func _init(p_coord: Vector2i, p_type_id: String) -> void:
	coord = p_coord
	type_id = p_type_id


func execute(ctx: Dictionary) -> void:
	var hex_grid: HexGrid = ctx.hex_grid as HexGrid
	var spatial: SpatialIndex = ctx.spatial as SpatialIndex

	var def: Dictionary = ContentDB.get_building_def(type_id)
	var validation: Dictionary = PlacementRulesRef.validate(coord, type_id, hex_grid)
	if not (validation.get("ok", false) as bool):
		message = validation.get("message", Localization.t("ui.command.cannot_build_here", "Cannot build here")) as String
		return

	# Spend & place
	var build_cost: Dictionary = def.get("build_cost", {})
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
	message = Localization.t("ui.command.built", "Built %s") % Localization.content_text(def, "label", type_id)
	EventBus.building_placed.emit(coord, type_id)
