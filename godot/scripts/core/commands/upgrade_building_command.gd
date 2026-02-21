class_name UpgradeBuildingCommand extends CommandBase
## Upgrades a building to the next level.

var coord: Vector2i


func _init(p_coord: Vector2i) -> void:
	coord = p_coord


func execute(ctx: Dictionary) -> void:
	if not GameStateStore.has_building(coord):
		message = "No building here"
		return

	var bld: Dictionary = GameStateStore.get_building(coord)
	var type_id: String = bld.get("type", "") as String
	var current_level: int = bld.get("level", 0) as int
	var max_level: int = ContentDB.max_building_level(type_id)

	if current_level + 1 >= max_level:
		message = "Already at max level"
		return

	var next_ldata: Dictionary = ContentDB.building_level_data(type_id, current_level + 1)
	var cost: Dictionary = next_ldata.get("cost", {})
	if cost.is_empty():
		message = "No upgrade available"
		return

	# Apply upgrade discount from aura
	var interactions: BuildingInteractions = ctx.get("interactions") as BuildingInteractions
	var discount: float = 0.0
	if interactions:
		discount = interactions.get_upgrade_discount(coord)
	var adjusted_cost: Dictionary = {}
	for res_id: String in cost:
		adjusted_cost[res_id] = (cost[res_id] as float) * maxf(1.0 - discount, 0.5)

	if not GameStateStore.can_afford(adjusted_cost):
		message = "Not enough resources"
		return

	GameStateStore.spend(adjusted_cost)
	bld["level"] = current_level + 1
	GameStateStore.set_building(coord, bld)

	# Invalidate caches
	if interactions:
		interactions.invalidate_caches()
	var coverage: CoverageMap = ctx.get("coverage") as CoverageMap
	if coverage:
		coverage.invalidate()

	success = true
	var stage: String = next_ldata.get("stage", "Level %d" % (current_level + 1)) as String
	message = "Upgraded to %s" % stage
	EventBus.building_upgraded.emit(coord, current_level + 1)
