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
	EventBus.coverage_recalculated.emit()
