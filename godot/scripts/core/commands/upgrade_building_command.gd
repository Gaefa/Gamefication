class_name UpgradeBuildingCommand
extends CommandBase

var q: int
var r: int

func _init(q_: int = 0, r_: int = 0) -> void:
	q = q_; r = r_

func execute(state: Dictionary, hex_grid: HexGrid, spatial_index: SpatialIndex) -> bool:
	var bld := hex_grid.get_building(q, r)
	if bld.is_empty():
		return false
	if bld.get("issue") != null:
		return false
	var bld_def := ContentDB.get_building(bld.type)
	if bld_def.is_empty():
		return false
	var levels: Array = bld_def.get("levels", [])
	if bld.level >= levels.size():
		return false
	var next_level: Dictionary = levels[bld.level]  # 0-indexed, current level is 1-based
	var cost: Dictionary = next_level.get("cost", {})
	if cost.is_empty() or cost == null:
		return false
	# Check resources
	var resources: Dictionary = state.economy.resources
	for k in cost:
		if resources.get(k, 0.0) < cost[k] - 0.001:
			return false
	# Spend
	for k in cost:
		resources[k] = maxf(0.0, resources.get(k, 0.0) - cost[k])
	bld.level += 1
	hex_grid.set_building(q, r, bld)
	state.meta["total_upgrades_done"] = state.meta.get("total_upgrades_done", 0) + 1
	EventBus.building_upgraded.emit(Vector2i(q, r), bld.level)
	EventBus.resources_changed.emit()
	EventBus.coverage_invalidated.emit()
	return true
