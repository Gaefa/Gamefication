class_name TerrainGenerator
## Procedural terrain generator for the hex map.
## Uses FBM noise + distance falloff to create an island-like map.

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


func _init(rng: SeededRNG, radius: int) -> void:
	_rng = rng
	_radius = radius
	_noise = NoiseProvider.new(rng)


func generate() -> void:
	var noise_scale: float = 0.06
	var coords: Array[Vector2i] = HexCoords.disk(Vector2i.ZERO, _radius)

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
		GameStateStore.set_terrain(coord, terrain_id)


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
