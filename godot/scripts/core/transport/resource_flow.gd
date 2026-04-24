class_name ResourceFlow
## Determines if a resource can reach a building based on transport type.
## Transport modes: "global" (stockpile), "road" (logistics), "pipe" (power utility coverage).

var _coverage: CoverageMap


func _init(coverage: CoverageMap) -> void:
	_coverage = coverage


func can_deliver(res_id: String, coord: Vector2i) -> bool:
	var def: Dictionary = ContentDB.get_resource_def(res_id)
	var transport: String = def.get("transport", "global") as String
	match transport:
		"global":
			return true
		"road":
			return _coverage.is_road_connected(coord)
		"pipe":
			return _can_deliver_utility(res_id, coord)
	return true


func delivery_efficiency(res_id: String, coord: Vector2i) -> float:
	if can_deliver(res_id, coord):
		return 1.0
	return 0.0  # No transport → no delivery


func input_efficiency_for(coord: Vector2i, consumes: Dictionary) -> float:
	## If any required input cannot reach the building, the building stalls.
	if consumes.is_empty():
		return 1.0
	var efficiency := 1.0
	for res_id: String in consumes:
		efficiency = minf(efficiency, delivery_efficiency(res_id, coord))
	return efficiency


func output_efficiency_for(res_id: String, coord: Vector2i, producer_type_id: String) -> float:
	## Utility producers define coverage, so they can always produce their own utility stock.
	if _is_native_utility_output(res_id, producer_type_id):
		return 1.0
	return delivery_efficiency(res_id, coord)


func _can_deliver_utility(res_id: String, coord: Vector2i) -> bool:
	if res_id == "energy":
		return _coverage.is_power_covered(coord)
	return _coverage.is_water_covered(coord)


func _is_native_utility_output(res_id: String, producer_type_id: String) -> bool:
	var is_power_output := res_id == "energy" and producer_type_id == "power"
	return is_power_output
