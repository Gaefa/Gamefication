## seeded_rng.gd -- Deterministic PRNG using the mulberry32 algorithm.
## Exact port of the JavaScript mulberry32 from mapgen.js for cross-platform
## deterministic parity.
##
## CRITICAL: GDScript integers are 64-bit.  JavaScript numbers overflow at 32 bits
## when using bitwise operators.  We simulate 32-bit unsigned wrapping by masking
## with 0xFFFFFFFF after every arithmetic operation that could overflow.
class_name SeededRNG


## Internal 32-bit seed state.
var rng_seed: int = 0


# ---- Lifecycle --------------------------------------------------------------

func _init(initial_seed: int = 0) -> void:
	rng_seed = initial_seed & 0xFFFFFFFF


# ---- Core mulberry32 -------------------------------------------------------

## Return the next pseudo-random float in [0, 1).
## This is a line-for-line port of mulberry32.
func next_float() -> float:
	# rng_seed = (rng_seed + 0x6D2B79F5) -- wrapping 32-bit add
	rng_seed = (rng_seed + 0x6D2B79F5) & 0xFFFFFFFF

	# var t = rng_seed ^ (rng_seed >>> 15)
	var t: int = (rng_seed ^ (rng_seed >> 15)) & 0xFFFFFFFF

	# t = t * (1 | rng_seed) -- wrapping 32-bit multiply
	# We must handle the multiply carefully to stay in 32-bit range.
	t = _wrap_mul(t, (1 | rng_seed))

	# t = (t + (t ^ (t >>> 7)) * (61 | t)) ^ t
	var inner: int = (t ^ (t >> 7)) & 0xFFFFFFFF
	var mul_result: int = _wrap_mul(inner, (61 | t))
	t = ((t + mul_result) & 0xFFFFFFFF) ^ t
	t = t & 0xFFFFFFFF

	# return ((t ^ (t >>> 14)) >>> 0) / 4294967296
	# In JS, >>> 0 coerces to uint32.  We mask with 0x7FFFFFFF for positive int,
	# matching the original spec.
	var final_bits: int = (t ^ (t >> 14)) & 0x7FFFFFFF
	return float(final_bits) / 2147483648.0


## Return a random integer in [0, max_val).
func next_int(max_val: int) -> int:
	return int(next_float() * max_val)


## Return a random float in [min_val, max_val).
func next_range(min_val: float, max_val: float) -> float:
	return min_val + next_float() * (max_val - min_val)


# ---- Internal helpers -------------------------------------------------------

## Wrapping 32-bit unsigned multiply.
## Splits operands into 16-bit halves to avoid 64-bit overflow issues,
## then recombines with masking.
static func _wrap_mul(a: int, b: int) -> int:
	a = a & 0xFFFFFFFF
	b = b & 0xFFFFFFFF
	var a_lo: int = a & 0xFFFF
	var a_hi: int = (a >> 16) & 0xFFFF
	var b_lo: int = b & 0xFFFF
	# Only the low 32 bits matter, so a_hi * b_hi is discarded entirely.
	# result = a_lo * b_lo + ((a_hi * b_lo + a_lo * b_hi) << 16)  [mod 2^32]
	var mid: int = (a_hi * b_lo + a_lo * ((b >> 16) & 0xFFFF)) & 0xFFFF
	return ((a_lo * b_lo) + (mid << 16)) & 0xFFFFFFFF
