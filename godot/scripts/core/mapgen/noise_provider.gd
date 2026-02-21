class_name NoiseProvider
## FBM (Fractal Brownian Motion) value noise generator.
## Uses SeededRNG for deterministic results.

var _rng: SeededRNG
var _perm: PackedInt32Array


func _init(rng: SeededRNG) -> void:
	_rng = rng
	_perm = PackedInt32Array()
	_perm.resize(512)
	# Build permutation table
	var base: Array[int] = []
	for i: int in 256:
		base.append(i)
	# Fisher-Yates shuffle
	for i: int in range(255, 0, -1):
		var j: int = _rng.range_int(0, i + 1)
		var tmp: int = base[i]
		base[i] = base[j]
		base[j] = tmp
	for i: int in 256:
		_perm[i] = base[i]
		_perm[i + 256] = base[i]


func fbm(x: float, y: float, octaves: int = 4, lacunarity: float = 2.0, gain: float = 0.5) -> float:
	var total: float = 0.0
	var amplitude: float = 1.0
	var frequency: float = 1.0
	var max_val: float = 0.0
	for _i: int in octaves:
		total += _value_noise(x * frequency, y * frequency) * amplitude
		max_val += amplitude
		amplitude *= gain
		frequency *= lacunarity
	return total / max_val


func _value_noise(x: float, y: float) -> float:
	var xi: int = int(floorf(x)) & 255
	var yi: int = int(floorf(y)) & 255
	var xf: float = x - floorf(x)
	var yf: float = y - floorf(y)
	var u: float = _fade(xf)
	var v: float = _fade(yf)
	var aa: int = _perm[_perm[xi] + yi]
	var ab: int = _perm[_perm[xi] + yi + 1]
	var ba: int = _perm[_perm[xi + 1] + yi]
	var bb: int = _perm[_perm[xi + 1] + yi + 1]
	var x1: float = lerpf(_hash_f(aa), _hash_f(ba), u)
	var x2: float = lerpf(_hash_f(ab), _hash_f(bb), u)
	return lerpf(x1, x2, v)


func _fade(t: float) -> float:
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


func _hash_f(h: int) -> float:
	return float(h & 255) / 255.0
