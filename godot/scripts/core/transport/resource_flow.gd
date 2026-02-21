class_name ResourceFlow
## Determines if a resource can reach a building based on transport type.
## Transport modes: "global" (instant), "road" (needs road network), "pipe".

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
			return _coverage.is_water_covered(coord)
	return true


func delivery_efficiency(res_id: String, coord: Vector2i) -> float:
	if can_deliver(res_id, coord):
		return 1.0
	return 0.0  # No transport → no delivery
