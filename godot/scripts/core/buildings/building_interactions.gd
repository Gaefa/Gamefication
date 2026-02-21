class_name BuildingInteractions
## Facade aggregating all building interaction queries.

var adjacency: AdjacencyCalculator
var aura_cache: AuraCache
var synergy: SynergyResolver
var production_mult: ProductionMultiplier


func _init(
	adj: AdjacencyCalculator,
	aura: AuraCache,
	syn: SynergyResolver,
	prod: ProductionMultiplier
) -> void:
	adjacency = adj
	aura_cache = aura
	synergy = syn
	production_mult = prod


func get_total_multipliers(coord: Vector2i) -> Dictionary:
	return production_mult.compute(coord)


func get_happiness_bonus(coord: Vector2i) -> float:
	return aura_cache.get_happiness_bonus(coord)


func get_upgrade_discount(coord: Vector2i) -> float:
	return aura_cache.get_upgrade_discount(coord)


func invalidate_caches() -> void:
	aura_cache.invalidate()
