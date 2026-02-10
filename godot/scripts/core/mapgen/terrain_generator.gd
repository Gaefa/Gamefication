## terrain_generator.gd -- Procedural hex terrain generator.
## Port of the JS mapgen.js terrain generation with island falloff.
## Uses NoiseProvider for FBM height maps and assigns terrain types.
##
## Terrain types (from terrain.json):
##   0 = grass     (default, buildable)
##   1 = water     (not buildable)
##   2 = sand      (buildable, cost x1.2)
##   3 = forest    (buildable, cost x1.5)
##   4 = mountain  (not buildable)
##   5 = swamp     (buildable, cost x1.8)
class_name TerrainGenerator


# Terrain type constants matching terrain.json order.
const TERRAIN_GRASS: int = 0
const TERRAIN_WATER: int = 1
const TERRAIN_SAND: int = 2
const TERRAIN_FOREST: int = 3
const TERRAIN_MOUNTAIN: int = 4
const TERRAIN_SWAMP: int = 5


# ------------------------------------------------------------------
# Public API
# ------------------------------------------------------------------

## Generate terrain for the given HexGrid using the provided seed.
## Fills hex_grid.terrain with type IDs.
func generate(hex_grid: HexGrid, seed_value: int) -> void:
	var size: int = hex_grid.grid_size

	# Create noise providers with different seeds for variety.
	var elevation_noise := NoiseProvider.new(size, seed_value, 16)
	var moisture_noise := NoiseProvider.new(size, seed_value + 1337, 20)
	var detail_noise := NoiseProvider.new(size, seed_value + 42, 8)

	var center: float = float(size) / 2.0

	for r in range(size):
		for q in range(size):
			# Convert axial to offset to get a grid position for noise sampling.
			var off: Vector2i = HexCoords.axial_to_offset(q, r)
			var ox: float = float(off.x)
			var oy: float = float(off.y)

			# Elevation from FBM noise
			var elevation: float = elevation_noise.fbm(ox, oy, 4, 0.5)

			# Island falloff -- distance from center, normalized to [0, 1]
			var dx: float = (ox - center) / center
			var dy: float = (oy - center) / center
			var dist: float = sqrt(dx * dx + dy * dy)

			# Smooth falloff: tiles near edges become water
			var falloff: float = 1.0 - clampf(dist * 1.4, 0.0, 1.0)
			falloff = falloff * falloff  # Quadratic falloff for rounder islands

			elevation = elevation * falloff

			# Moisture from separate noise
			var moisture: float = moisture_noise.fbm(ox, oy, 3, 0.6)

			# Detail noise for variety
			var detail: float = detail_noise.fbm(ox, oy, 2, 0.4)

			# Classify terrain
			var terrain_type: int = _classify(elevation, moisture, detail)
			hex_grid.set_terrain(q, r, terrain_type)


# ------------------------------------------------------------------
# Terrain classification
# ------------------------------------------------------------------

func _classify(elevation: float, moisture: float, detail: float) -> int:
	# Deep water
	if elevation < 0.15:
		return TERRAIN_WATER

	# Shallow water / beach transition
	if elevation < 0.22:
		if detail > 0.5:
			return TERRAIN_SAND
		return TERRAIN_WATER

	# Sand (beaches, dry low areas)
	if elevation < 0.28:
		return TERRAIN_SAND

	# Mountains (high elevation)
	if elevation > 0.72:
		return TERRAIN_MOUNTAIN

	# High hills that are rocky
	if elevation > 0.62 and moisture < 0.4:
		return TERRAIN_MOUNTAIN

	# Swamp (low elevation + high moisture)
	if elevation < 0.38 and moisture > 0.6:
		return TERRAIN_SWAMP

	# Forest (mid elevation + mid-high moisture)
	if moisture > 0.5 and elevation > 0.3:
		if detail > 0.35:
			return TERRAIN_FOREST

	# Everything else is grass
	return TERRAIN_GRASS
