## hex_coords.gd -- Static utility class for flat-top hexagonal coordinate math.
## Convention: flat-top hexagons, axial coordinates (q, r) internally.
## All methods are static -- no instance state needed.
class_name HexCoords


## The six axial-coordinate direction vectors for flat-top hexagons,
## ordered clockwise starting from East (right).
const AXIAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),   # 0 - East
	Vector2i(1, -1),  # 1 - NE
	Vector2i(0, -1),  # 2 - NW
	Vector2i(-1, 0),  # 3 - West
	Vector2i(-1, 1),  # 4 - SW
	Vector2i(0, 1),   # 5 - SE
]

## Pre-computed sqrt(3) to avoid recalculating.
const SQRT3: float = 1.7320508075688772


# ---- Coordinate conversions ------------------------------------------------

## Convert axial (q, r) to offset (col, row) -- odd-r offset layout.
static func axial_to_offset(q: int, r: int) -> Vector2i:
	var col: int = q + (r - (r & 1)) / 2
	var row: int = r
	return Vector2i(col, row)


## Convert offset (col, row) to axial (q, r) -- odd-r offset layout.
static func offset_to_axial(col: int, row: int) -> Vector2i:
	var q: int = col - (row - (row & 1)) / 2
	var r: int = row
	return Vector2i(q, r)


## Convert axial (q, r) to cube (x, y, z) where x=q, y=r, z=-q-r.
static func axial_to_cube(q: int, r: int) -> Vector3i:
	return Vector3i(q, r, -q - r)


## Convert cube (x, y, z) back to axial (q, r).
static func cube_to_axial(cube: Vector3i) -> Vector2i:
	return Vector2i(cube.x, cube.y)


# ---- Distance ---------------------------------------------------------------

## Manhattan distance in cube coordinates.
static func cube_distance(a: Vector3i, b: Vector3i) -> int:
	return (abs(a.x - b.x) + abs(a.y - b.y) + abs(a.z - b.z)) / 2


## Hex distance between two axial coords -- delegates to cube_distance.
static func hex_distance(q1: int, r1: int, q2: int, r2: int) -> int:
	return cube_distance(axial_to_cube(q1, r1), axial_to_cube(q2, r2))


# ---- Neighbors --------------------------------------------------------------

## Return all 6 axial-coordinate neighbors of (q, r).
static func axial_neighbors(q: int, r: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.resize(6)
	for i in 6:
		result[i] = Vector2i(q + AXIAL_DIRECTIONS[i].x, r + AXIAL_DIRECTIONS[i].y)
	return result


## Return the single neighbor of (q, r) in the given direction (0-5).
static func axial_neighbor(q: int, r: int, direction: int) -> Vector2i:
	var d: Vector2i = AXIAL_DIRECTIONS[direction % 6]
	return Vector2i(q + d.x, r + d.y)


# ---- Ring & Spiral ----------------------------------------------------------

## All hexes at exactly the given [param radius] from the center.
## If radius == 0, returns [center].
## Uses the standard hex ring algorithm: start at direction 4 scaled by radius,
## then walk 6 edges of length [param radius].
static func ring(center_q: int, center_r: int, radius: int) -> Array[Vector2i]:
	if radius == 0:
		return [Vector2i(center_q, center_r)] as Array[Vector2i]

	var results: Array[Vector2i] = []
	# Start hex: center + direction[4] * radius  (SW direction)
	var q: int = center_q + AXIAL_DIRECTIONS[4].x * radius
	var r: int = center_r + AXIAL_DIRECTIONS[4].y * radius

	for edge in 6:
		for _step in radius:
			results.append(Vector2i(q, r))
			var d: Vector2i = AXIAL_DIRECTIONS[edge]
			q += d.x
			r += d.y

	return results


## Center hex + all rings from 1 to [param radius] (filled disc).
static func spiral(center_q: int, center_r: int, radius: int) -> Array[Vector2i]:
	var results: Array[Vector2i] = [Vector2i(center_q, center_r)]
	for k in range(1, radius + 1):
		results.append_array(ring(center_q, center_r, k))
	return results


# ---- Bounds check -----------------------------------------------------------

## Check whether axial (q, r) falls within a square grid of [param grid_size].
## Converts to offset and checks 0 <= col < grid_size and 0 <= row < grid_size.
static func is_valid(q: int, r: int, grid_size: int) -> bool:
	var off: Vector2i = axial_to_offset(q, r)
	return off.x >= 0 and off.x < grid_size and off.y >= 0 and off.y < grid_size


# ---- Pixel conversion (flat-top) -------------------------------------------

## Convert axial (q, r) to pixel position for flat-top hexagons.
## Returns the center of the hex in world space.
static func axial_to_pixel(q: int, r: int, hex_size: float) -> Vector2:
	var x: float = hex_size * (1.5 * q)
	var y: float = hex_size * (SQRT3 * 0.5 * q + SQRT3 * r)
	return Vector2(x, y)


## Convert pixel position to the nearest axial hex coordinate (flat-top).
## Uses fractional cube coordinates and rounds to the nearest hex.
static func pixel_to_axial(x: float, y: float, hex_size: float) -> Vector2i:
	# Inverse of axial_to_pixel for flat-top:
	var fq: float = (2.0 / 3.0 * x) / hex_size
	var fr: float = (-1.0 / 3.0 * x + SQRT3 / 3.0 * y) / hex_size
	return _axial_round(fq, fr)


## Round fractional axial coordinates to the nearest integer hex.
## Converts to cube, rounds, picks the coord with largest rounding error
## to fix, then converts back.
static func _axial_round(fq: float, fr: float) -> Vector2i:
	var fs: float = -fq - fr

	var rq: int = roundi(fq)
	var rr: int = roundi(fr)
	var rs: int = roundi(fs)

	var dq: float = absf(float(rq) - fq)
	var dr: float = absf(float(rr) - fr)
	var ds: float = absf(float(rs) - fs)

	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	# else: rs = -rq - rr  (not needed since we only return q, r)

	return Vector2i(rq, rr)
