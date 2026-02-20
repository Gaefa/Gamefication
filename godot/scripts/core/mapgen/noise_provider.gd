## noise_provider.gd -- 2D value noise generator using SeededRNG.
## Port of createNoise2D from the JS mapgen.js.
## Generates a lattice of random values and interpolates between them
## with cosine smoothing.  Supports Fractal Brownian Motion (FBM).
class_name NoiseProvider


## Lattice cell size in "noise space".
var _grid_size: int = 16

## The random lattice values.  Indexed as _lattice[y * _lattice_w + x].
var _lattice: PackedFloat64Array = PackedFloat64Array()
var _lattice_w: int = 0
var _lattice_h: int = 0

## SeededRNG used for deterministic lattice generation.
var _rng: SeededRNG = null


# ------------------------------------------------------------------
# Lifecycle
# ------------------------------------------------------------------

## Initialize the noise lattice for a map of [param map_size] with the given
## [param seed_value] and optional [param cell_size].
func _init(map_size: int, seed_value: int, cell_size: int = 16) -> void:
	_grid_size = cell_size
	_rng = SeededRNG.new(seed_value)

	# Lattice needs to cover the map + 1 extra cell on each edge for interpolation.
	_lattice_w = (map_size / _grid_size) + 2
	_lattice_h = (map_size / _grid_size) + 2
	_lattice.resize(_lattice_w * _lattice_h)

	for i in range(_lattice.size()):
		_lattice[i] = _rng.next_float()


# ------------------------------------------------------------------
# Single sample
# ------------------------------------------------------------------

## Sample the noise at continuous coordinates (x, y).
## Returns a value roughly in [0, 1].
func sample(x: float, y: float) -> float:
	var gx: float = x / float(_grid_size)
	var gy: float = y / float(_grid_size)

	var ix: int = int(floor(gx))
	var iy: int = int(floor(gy))

	var fx: float = gx - float(ix)
	var fy: float = gy - float(iy)

	# Cosine interpolation weights
	var wx: float = (1.0 - cos(fx * PI)) * 0.5
	var wy: float = (1.0 - cos(fy * PI)) * 0.5

	var v00: float = _lattice_at(ix, iy)
	var v10: float = _lattice_at(ix + 1, iy)
	var v01: float = _lattice_at(ix, iy + 1)
	var v11: float = _lattice_at(ix + 1, iy + 1)

	var top: float = lerp(v00, v10, wx)
	var bot: float = lerp(v01, v11, wx)

	return lerp(top, bot, wy)


# ------------------------------------------------------------------
# Fractal Brownian Motion
# ------------------------------------------------------------------

## Sample FBM noise with the given number of octaves.
## Each octave doubles frequency and halves amplitude (persistence = 0.5).
func fbm(x: float, y: float, octaves: int = 4, persistence: float = 0.5) -> float:
	var total: float = 0.0
	var amplitude: float = 1.0
	var frequency: float = 1.0
	var max_value: float = 0.0

	for _i in octaves:
		total += sample(x * frequency, y * frequency) * amplitude
		max_value += amplitude
		amplitude *= persistence
		frequency *= 2.0

	return total / max_value if max_value > 0.0 else 0.0


# ------------------------------------------------------------------
# Internal
# ------------------------------------------------------------------

## Safe lattice lookup with wrapping.
func _lattice_at(ix: int, iy: int) -> float:
	# Clamp to lattice bounds
	ix = clampi(ix, 0, _lattice_w - 1)
	iy = clampi(iy, 0, _lattice_h - 1)
	var idx: int = iy * _lattice_w + ix
	if idx < 0 or idx >= _lattice.size():
		return 0.5
	return _lattice[idx]
