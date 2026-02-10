class_name InfrastructureSystem

static func process_tick(state: Dictionary, hex_grid: HexGrid, transport_graph: TransportGraph, coverage_map: CoverageMap, spatial_index: SpatialIndex) -> void:
	transport_graph.ensure_fresh(hex_grid)
	coverage_map.ensure_fresh(hex_grid, spatial_index)
