class_name PlaceBuildingCommand
extends CommandBase

var q: int
var r: int
var type_id: String

func _init(q_: int = 0, r_: int = 0, type_: String = "") -> void:
	q = q_; r = r_; type_id = type_

func execute(state: Dictionary, hex_grid: HexGrid, spatial_index: SpatialIndex) -> bool:
	if not hex_grid.is_valid_coord(q, r):
		return false
	if hex_grid.has_building(q, r):
		return false
	var terrain_type := hex_grid.get_terrain(q, r)
	var terrain_def := ContentDB.get_terrain_type(terrain_type)
	if not terrain_def.get("buildable", false):
		return false
	var bld_def := ContentDB.get_building(type_id)
	if bld_def.is_empty():
		return false
	if bld_def.get("unlock_level", 1) > state.progression.city_level:
		return false
	var base_cost: Dictionary = bld_def.get("build_cost", {})
	var cost_mult: float = terrain_def.get("cost_multiplier", 1.0)
	var final_cost := {}
	for k in base_cost:
		final_cost[k] = base_cost[k] * cost_mult
	var resources: Dictionary = state.economy.resources
	for k in final_cost:
		if resources.get(k, 0.0) < final_cost[k] - 0.001:
			return false
	for k in final_cost:
		resources[k] = maxf(0.0, resources.get(k, 0.0) - final_cost[k])
	var building := {"type": type_id, "level": 1, "issue": null}
	hex_grid.set_building(q, r, building)
	spatial_index.add(Vector2i(q, r), type_id)
	state.meta["total_buildings_placed"] = state.meta.get("total_buildings_placed", 0) + 1
	EventBus.building_placed.emit(Vector2i(q, r), type_id)
	EventBus.resources_changed.emit()
	EventBus.network_invalidated.emit()
	EventBus.coverage_invalidated.emit()
	return true
