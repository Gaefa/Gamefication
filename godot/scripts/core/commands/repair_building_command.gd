class_name RepairBuildingCommand extends CommandBase
## Repairs a damaged building for a small coin cost.

var coord: Vector2i

const REPAIR_COST_COINS := 20.0


func _init(p_coord: Vector2i) -> void:
	coord = p_coord


func execute(_ctx: Dictionary) -> void:
	if not GameStateStore.has_building(coord):
		message = "No building here"
		return

	var bld: Dictionary = GameStateStore.get_building(coord)
	var is_damaged: bool = bld.get("damaged", false) as bool
	var has_issue: bool = bld.get("has_issue", false) as bool
	if not is_damaged and not has_issue:
		message = "Building is fine"
		return

	if not GameStateStore.can_afford({"coins": REPAIR_COST_COINS}):
		message = "Need %d coins" % int(REPAIR_COST_COINS)
		return

	GameStateStore.spend({"coins": REPAIR_COST_COINS})
	bld["damaged"] = false
	bld["has_issue"] = false
	GameStateStore.set_building(coord, bld)

	success = true
	message = "Building repaired"
	EventBus.building_repaired.emit(coord)
