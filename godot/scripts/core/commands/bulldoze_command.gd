class_name BulldozeCommand extends CommandBase
## Removes a building, refunding 10% of build cost.

var coord: Vector2i
## Set by scripted events (the fate of the old tower): the player alone cannot remove
## the district's fixed buildings.
var force: bool = false


func _init(p_coord: Vector2i, p_force: bool = false) -> void:
	coord = p_coord
	force = p_force


## The Cistern, the admin post and the landmarks are not the player's to demolish: losing
## the Cistern would drop the water cap for good. Ruins are fair game — they yield salvage.
static func is_protected(def: Dictionary) -> bool:
	return not (def.get("player_buildable", true) as bool) and not def.has("salvage")


## A damaged shelter has no beds (ProgressionSystem skips it), so it is not a home here either.
func _is_last_home(bld: Dictionary, type_id: String) -> bool:
	if bld.get("damaged", false) as bool or (ContentDB.building_level_data(type_id, bld.get("level", 0) as int).get("population", 0) as int) <= 0:
		return false
	var homes: int = 0
	for other: Vector2i in GameStateStore.get_all_building_coords():
		var other_bld: Dictionary = GameStateStore.get_building(other)
		if other_bld.get("damaged", false) as bool:
			continue
		if (ContentDB.building_level_data(other_bld.get("type", "") as String, other_bld.get("level", 0) as int).get("population", 0) as int) > 0:
			homes += 1
	return homes <= 1


func execute(ctx: Dictionary) -> void:
	if not GameStateStore.has_building(coord):
		message = Localization.t("ui.command.nothing_to_bulldoze", "Nothing to bulldoze")
		return

	var bld: Dictionary = GameStateStore.get_building(coord)
	var type_id: String = bld.get("type", "") as String
	var def: Dictionary = ContentDB.get_building_def(type_id)
	var spatial: SpatialIndex = ctx.spatial as SpatialIndex
	if not force and is_protected(def):
		message = Localization.ru_en("Это здание нельзя снести", "This building cannot be demolished")
		return
	# A district keeps at least one home: demolishing the only one empties it at once, and an
	# empty district is a lost game.
	if not force and _is_last_home(bld, type_id):
		message = Localization.ru_en("Это последнее жильё: людям некуда идти. Сначала постройте другой барак.",
			"This is the last housing: people have nowhere to go. Build another shelter first.")
		return

	# Refund 10%
	var build_cost: Dictionary = def.get("build_cost", {})
	for res_id: String in build_cost:
		var refund: float = (build_cost[res_id] as float) * 0.1
		GameStateStore.add_resource(res_id, refund)
	# Ruins of the old owner yield salvage instead (content: "salvage").
	var salvage: Dictionary = def.get("salvage", {})
	for res_id: String in salvage:
		GameStateStore.add_resource(res_id, salvage[res_id] as float)

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
	message = Localization.t("ui.command.bulldozed", "Bulldozed %s") % Localization.content_text(def, "label", type_id)
	EventBus.building_removed.emit(coord, type_id)
