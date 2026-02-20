class_name BulldozeCommand
extends CommandBase

var q: int
var r: int

func _init(q_: int = 0, r_: int = 0) -> void:
	q = q_; r = r_

func execute(state: Dictionary, hex_grid: HexGrid, spatial_index: SpatialIndex) -> bool:
	if not hex_grid.has_building(q, r):
		return false
	var bld := hex_grid.get_building(q, r)
	# Refund 10% of build cost
	var bld_def := ContentDB.get_building(bld.get("type", ""))
	if not bld_def.is_empty():
		var base_cost: Dictionary = bld_def.get("build_cost", {})
		for k in base_cost:
			var refund: float = base_cost[k] * 0.1
			state.economy.resources[k] = state.economy.resources.get(k, 0.0) + refund
	hex_grid.remove_building(q, r)
	spatial_index.remove(Vector2i(q, r))
	EventBus.building_removed.emit(Vector2i(q, r))
	EventBus.resources_changed.emit()
	EventBus.network_invalidated.emit()
	EventBus.coverage_invalidated.emit()
	return true
