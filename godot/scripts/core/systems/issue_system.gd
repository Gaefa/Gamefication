class_name IssueSystem

static func process_tick(state: Dictionary, hex_grid: HexGrid, road_network: RoadNetwork, pipe_network: PipeNetwork, spatial_index: SpatialIndex, coverage_map: CoverageMap) -> void:
	var buildings := hex_grid.get_all_buildings()
	for coord in buildings:
		var bld: Dictionary = buildings[coord]
		if bld.get("type", "") == "road":
			continue
		if bld.get("issue") != null:
			continue
		var chance: float = 0.001 + bld.get("level", 1) * 0.00035
		if randf() >= chance:
			continue
		var possible_issues: Array = []
		var bld_def := ContentDB.get_building(bld.get("type", ""))
		if bld_def.get("requires_road", false) and not road_network.is_building_connected(coord.x, coord.y, hex_grid):
			possible_issues.append("Traffic")
		if bld.get("type", "") != "power" and bld.get("type", "") != "road":
			if not coverage_map.is_powered(coord.x, coord.y):
				possible_issues.append("Power")
		if bld.get("type", "") in ["hut", "apartment"]:
			if not coverage_map.is_water_covered(coord.x, coord.y):
				possible_issues.append("Water")
		possible_issues.append("Maintenance")
		if bld.get("level", 1) >= 2:
			possible_issues.append("Supply")
		bld["issue"] = possible_issues[randi() % possible_issues.size()]
		hex_grid.set_building(coord.x, coord.y, bld)

static func force_issues(state: Dictionary, hex_grid: HexGrid, count: int) -> void:
	var candidates: Array = []
	var buildings := hex_grid.get_all_buildings()
	for coord in buildings:
		var bld: Dictionary = buildings[coord]
		if bld.get("type", "") != "road" and bld.get("issue") == null:
			candidates.append({"coord": coord, "bld": bld})
	candidates.shuffle()
	for i in range(mini(count, candidates.size())):
		candidates[i].bld["issue"] = "Emergency"
		hex_grid.set_building(candidates[i].coord.x, candidates[i].coord.y, candidates[i].bld)
