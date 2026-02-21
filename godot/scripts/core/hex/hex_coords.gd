class_name HexCoords
## Static utilities for flat-top axial hex coordinates.
## Axial coords: (q, r).  Cube coords: (q, r, s) where s = -q - r.

# Flat-top hex dimensions given a tile "size" (center to corner).
const HEX_SIZE := 32.0

## Six flat-top neighbor offsets in axial coords.
## Order: E, NE, NW, W, SW, SE
const NEIGHBORS: Array[Vector2i] = [
	Vector2i( 1,  0), Vector2i( 1, -1), Vector2i( 0, -1),
	Vector2i(-1,  0), Vector2i(-1,  1), Vector2i( 0,  1),
]


static func neighbors_of(coord: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset: Vector2i in NEIGHBORS:
		result.append(coord + offset)
	return result


static func distance(a: Vector2i, b: Vector2i) -> int:
	var dq := absi(a.x - b.x)
	var dr := absi(a.y - b.y)
	var ds := absi((-a.x - a.y) - (-b.x - b.y))
	return maxi(dq, maxi(dr, ds))


static func ring(center: Vector2i, radius: int) -> Array[Vector2i]:
	if radius <= 0:
		return [center]
	var results: Array[Vector2i] = []
	var cur := center + NEIGHBORS[4] * radius  # start SW
	for side: int in 6:
		for _step: int in radius:
			results.append(cur)
			cur = cur + NEIGHBORS[side]
	return results


static func disk(center: Vector2i, radius: int) -> Array[Vector2i]:
	var results: Array[Vector2i] = []
	for r: int in range(0, radius + 1):
		if r == 0:
			results.append(center)
		else:
			results.append_array(ring(center, r))
	return results


## Convert axial (q, r) to flat-top pixel position.
static func axial_to_pixel(coord: Vector2i) -> Vector2:
	var q := float(coord.x)
	var r := float(coord.y)
	var x := HEX_SIZE * (1.5 * q)
	var y := HEX_SIZE * (sqrt(3.0) * (r + q * 0.5))
	return Vector2(x, y)


## Convert pixel position to the nearest axial coordinate.
static func pixel_to_axial(pixel: Vector2) -> Vector2i:
	var q := pixel.x / (HEX_SIZE * 1.5)
	var r := (pixel.y / (HEX_SIZE * sqrt(3.0))) - q * 0.5
	return _axial_round(q, r)


static func _axial_round(q: float, r: float) -> Vector2i:
	var s := -q - r
	var rq := roundf(q)
	var rr := roundf(r)
	var rs := roundf(s)
	var dq := absf(rq - q)
	var dr := absf(rr - r)
	var ds := absf(rs - s)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	return Vector2i(int(rq), int(rr))
