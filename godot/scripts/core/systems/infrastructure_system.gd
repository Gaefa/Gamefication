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
	# Accumulate per-resource storage from all buildings
	var extra_caps: Dictionary = {}
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var bld: Dictionary = GameStateStore.get_building(coord)
		var type_id: String = bld.get("type", "") as String
		var level: int = bld.get("level", 0) as int
		var ldata: Dictionary = ContentDB.building_level_data(type_id, level)
		var storage_val: Variant = ldata.get("storage", null)
		if storage_val is Dictionary:
			# Per-resource storage (e.g. {"res_water_stockpile": 500})
			for res_id: String in storage_val as Dictionary:
				var canonical: String = GameStateStore._canonical(res_id)
				extra_caps[canonical] = (extra_caps.get(canonical, 0.0) as float) + (storage_val as Dictionary)[res_id] as float
		elif storage_val is float or storage_val is int:
			# Legacy scalar storage — apply to all warehoused resources
			var amount: float = storage_val as float
			for res_id: String in ContentDB.get_resource_ids():
				if _warehouse_storage_applies_to(res_id):
					extra_caps[res_id] = (extra_caps.get(res_id, 0.0) as float) + amount

	for res_id: String in ContentDB.get_resource_ids():
		var def: Dictionary = ContentDB.get_resource_def(res_id)
		var cap: float = def.get("default_cap", 9999.0) as float
		cap += extra_caps.get(res_id, 0.0) as float
		GameStateStore.set_cap(res_id, cap)
		if GameStateStore.get_resource(res_id) > cap:
			GameStateStore.set_resource(res_id, cap)


func _warehouse_storage_applies_to(res_id: String) -> bool:
	return not ["res_money", "coins", "fame", "res_water_stockpile", "water_res"].has(res_id)
