class_name PipeNetwork
## Water and power distribution network.
## Simply delegates to CoverageMap for coverage checks.

var _coverage: CoverageMap


func _init(coverage: CoverageMap) -> void:
	_coverage = coverage


func is_water_supplied(coord: Vector2i) -> bool:
	return _coverage.is_water_covered(coord)


func is_power_supplied(coord: Vector2i) -> bool:
	return _coverage.is_power_covered(coord)
