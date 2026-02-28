class_name SeededRNG
## Mulberry32 deterministic PRNG.
## Matches the JavaScript implementation for cross-platform parity.
## GDScript ints are 64-bit; we mask with 0xFFFFFFFF to simulate 32-bit.

const MASK := 0xFFFFFFFF

var _state: int


func _init(rng_seed: int = 12345) -> void:
	_state = rng_seed & MASK


func next_int() -> int:
	_state = (_state + 0x6D2B79F5) & MASK
	var t: int = _state
	t = ((t ^ (t >> 15)) * (t | 1)) & MASK
	t = (t ^ ((t + ((t ^ (t >> 7)) * (t | 61))) & MASK)) & MASK
	t = (t ^ (t >> 14)) & MASK
	return t


func next_float() -> float:
	return float(next_int()) / float(MASK + 1)


func range_int(low: int, high: int) -> int:
	if low >= high:
		return low
	return low + (next_int() % (high - low))


func range_float(low: float, high: float) -> float:
	return low + next_float() * (high - low)


func chance(probability: float) -> bool:
	return next_float() < probability
