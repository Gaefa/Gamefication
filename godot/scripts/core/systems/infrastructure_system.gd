class_name InfrastructureSystem
## Ensures all network caches are fresh before other systems run.

var _coverage: CoverageMap
var _road_graph: TransportGraph
var _aura_cache: AuraCache


func _init(coverage: CoverageMap, road_graph: TransportGraph, aura_cache: AuraCache) -> void:
	_coverage = coverage
	_road_graph = road_graph
	_aura_cache = aura_cache


func process_tick() -> void:
	_coverage.ensure_fresh()
	_road_graph.ensure_fresh()
	_aura_cache.ensure_fresh()
	_recalculate_storage_caps()
	EventBus.coverage_recalculated.emit()


func _recalculate_storage_caps() -> void:
	var shared_storage := 0.0
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var bld: Dictionary = GameStateStore.get_building(coord)
		var type_id: String = bld.get("type", "") as String
		var level: int = bld.get("level", 0) as int
		var ldata: Dictionary = ContentDB.building_level_data(type_id, level)
		shared_storage += ldata.get("storage", 0.0) as float

	for res_id: String in ContentDB.get_resource_ids():
		var def: Dictionary = ContentDB.get_resource_def(res_id)
		var cap: float = def.get("default_cap", 9999.0) as float
		if _warehouse_storage_applies_to(res_id):
			cap += shared_storage
		GameStateStore.set_cap(res_id, cap)
		if GameStateStore.get_resource(res_id) > cap:
			GameStateStore.set_resource(res_id, cap)


func _warehouse_storage_applies_to(res_id: String) -> bool:
	return not ["coins", "fame", "water_res"].has(res_id)
