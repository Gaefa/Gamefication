class_name RepairBuildingCommand
extends CommandBase

var q: int
var r: int

func _init(q_: int = 0, r_: int = 0) -> void:
	q = q_; r = r_

func execute(state: Dictionary, hex_grid: HexGrid, spatial_index: SpatialIndex) -> bool:
	var bld := hex_grid.get_building(q, r)
	if bld.is_empty():
		return false
	if bld.get("issue") == null:
		return false
	var base: int = 12 * bld.level
	var cost := {"coins": float(base), "tools": float(maxi(2, base / 8))}
	var resources: Dictionary = state.economy.resources
	for k in cost:
		if resources.get(k, 0.0) < cost[k] - 0.001:
			return false
	for k in cost:
		resources[k] = maxf(0.0, resources.get(k, 0.0) - cost[k])
	bld["issue"] = null
	hex_grid.set_building(q, r, bld)
	EventBus.resources_changed.emit()
	return true
