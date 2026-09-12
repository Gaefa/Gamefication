class_name TerrainGenerator
## Procedural terrain generator for the hex map.
## Uses FBM noise + distance falloff, then applies gameplay guarantees:
## readable clusters, safe start area, and early-game resources near the center.

var _rng: SeededRNG
var _radius: int
var _noise: NoiseProvider

# Terrain type IDs (matching terrain.json keys)
const GRASS := 0
const WATER := 1
const SAND := 2
const HILL := 3
const FOREST := 4
const ROCK := 5

# Noise thresholds
const WATER_THRESHOLD := 0.28
const SAND_THRESHOLD := 0.35
const FOREST_THRESHOLD := 0.55
const HILL_THRESHOLD := 0.68
const ROCK_THRESHOLD := 0.82

const START_SAFE_RADIUS := 3
const START_RESOURCE_RADIUS := 7
const SMOOTHING_PASSES := 2


func _init(rng: SeededRNG, radius: int) -> void:
	_rng = rng
	_radius = radius
	_noise = NoiseProvider.new(rng)


func generate() -> void:
	var noise_scale: float = 0.06
	var coords: Array[Vector2i] = HexCoords.disk(Vector2i.ZERO, _radius)
	var terrain: Dictionary = {}

	for coord: Vector2i in coords:
		var pixel: Vector2 = HexCoords.axial_to_pixel(coord)
		var nx: float = pixel.x * noise_scale
		var ny: float = pixel.y * noise_scale

		# FBM noise value
		var n: float = _noise.fbm(nx, ny, 4, 2.0, 0.5)

		# Distance falloff (island shape)
		var dist: float = float(HexCoords.distance(Vector2i.ZERO, coord)) / float(_radius)
		var falloff: float = 1.0 - dist * dist
		n *= maxf(falloff, 0.0)

		# Classify terrain
		var terrain_id: int = _classify(n)
		terrain[coord] = terrain_id

	_smooth_clusters(terrain, coords)
	_apply_start_guarantees(terrain)

	for coord: Vector2i in coords:
		GameStateStore.set_terrain(coord, terrain.get(coord, GRASS) as int)


func _classify(value: float) -> int:
	if value < WATER_THRESHOLD:
		return WATER
	elif value < SAND_THRESHOLD:
		return SAND
	elif value < FOREST_THRESHOLD:
		return GRASS
	elif value < HILL_THRESHOLD:
		return FOREST
	elif value < ROCK_THRESHOLD:
		return HILL
	else:
		return ROCK


func _smooth_clusters(terrain: Dictionary, coords: Array[Vector2i]) -> void:
	## Removes single-cell noise while preserving larger biome shapes.
	for _pass: int in SMOOTHING_PASSES:
		var prev: Dictionary = terrain.duplicate()
		for coord: Vector2i in coords:
			var own: int = prev.get(coord, GRASS) as int
			var counts: Dictionary = _neighbor_counts(prev, coord)
			var majority: int = _majority_terrain(counts, own)
			var majority_count: int = counts.get(majority, 0) as int
			var own_count: int = counts.get(own, 0) as int
			if majority != own and majority_count >= 4 and own_count <= 1:
				terrain[coord] = majority


func _neighbor_counts(terrain: Dictionary, coord: Vector2i) -> Dictionary:
	var counts: Dictionary = {}
	for nb: Vector2i in HexCoords.neighbors_of(coord):
		if HexCoords.distance(Vector2i.ZERO, nb) > _radius:
			continue
		var t: int = terrain.get(nb, GRASS) as int
		counts[t] = (counts.get(t, 0) as int) + 1
	return counts


func _majority_terrain(counts: Dictionary, fallback: int) -> int:
	var best: int = fallback
	var best_count: int = -1
	for terrain_id: int in counts:
		var count: int = counts[terrain_id] as int
		if count > best_count:
			best = terrain_id
			best_count = count
	return best


func _apply_start_guarantees(terrain: Dictionary) -> void:
	## The first minutes must always be playable: buildable core, farm land,
	## forest for wood, and rock/hill for quarry bonuses.
	_paint_disk(terrain, Vector2i.ZERO, START_SAFE_RADIUS, GRASS)
	_paint_ring_soft(terrain, Vector2i.ZERO, START_SAFE_RADIUS + 1, SAND)

	var forest_center := Vector2i(START_RESOURCE_RADIUS, -2)
	var rock_center := Vector2i(-START_RESOURCE_RADIUS, 3)
	var hill_center := Vector2i(2, START_RESOURCE_RADIUS - 1)

	_paint_cluster(terrain, forest_center, 2, FOREST, GRASS)
	_paint_cluster(terrain, rock_center, 2, ROCK, HILL)
	_paint_cluster(terrain, hill_center, 2, HILL, GRASS)

	# Keep direct expansion lanes from the center buildable.
	for dir: Vector2i in HexCoords.NEIGHBORS:
		for step: int in range(1, START_SAFE_RADIUS + 3):
			var c := dir * step
			if HexCoords.distance(Vector2i.ZERO, c) <= _radius:
				var current: int = terrain.get(c, GRASS) as int
				if current == WATER:
					terrain[c] = GRASS


func _paint_disk(terrain: Dictionary, center: Vector2i, radius: int, terrain_id: int) -> void:
	for coord: Vector2i in HexCoords.disk(center, radius):
		if HexCoords.distance(Vector2i.ZERO, coord) <= _radius:
			terrain[coord] = terrain_id


func _paint_ring_soft(terrain: Dictionary, center: Vector2i, radius: int, terrain_id: int) -> void:
	for coord: Vector2i in HexCoords.ring(center, radius):
		if HexCoords.distance(Vector2i.ZERO, coord) <= _radius:
			var current: int = terrain.get(coord, GRASS) as int
			if current == WATER:
				terrain[coord] = terrain_id


func _paint_cluster(terrain: Dictionary, center: Vector2i, radius: int, core_terrain: int, edge_terrain: int) -> void:
	for coord: Vector2i in HexCoords.disk(center, radius):
		if HexCoords.distance(Vector2i.ZERO, coord) > _radius:
			continue
		var dist: int = HexCoords.distance(center, coord)
		terrain[coord] = core_terrain if dist <= radius - 1 else edge_terrain
