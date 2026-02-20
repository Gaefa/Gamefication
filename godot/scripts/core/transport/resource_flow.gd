class_name ResourceFlow

static func get_transport_type(resource_id: String) -> String:
	var res_def := ContentDB.get_resource_def(resource_id)
	return res_def.get("transport", "global")

static func can_receive_resource(q: int, r: int, resource_id: String, road_network: RoadNetwork, pipe_network: PipeNetwork, hex_grid: HexGrid, spatial_index: SpatialIndex) -> bool:
	match get_transport_type(resource_id):
		"global":
			return true
		"road":
			return road_network.is_building_connected(q, r, hex_grid)
		"pipe":
			if resource_id == "energy":
				return pipe_network.has_energy(q, r, hex_grid, spatial_index)
			if resource_id == "water_res":
				return pipe_network.has_water(q, r, hex_grid, spatial_index)
	return true

static func get_connectivity_multiplier(q: int, r: int, building_type: String, road_network: RoadNetwork, hex_grid: HexGrid) -> float:
	var bld_def := ContentDB.get_building(building_type)
	if bld_def.get("requires_road", false) and not road_network.is_building_connected(q, r, hex_grid):
		return 0.3
	return 1.0
