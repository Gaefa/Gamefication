class_name FloodSystem
## Chapter mechanic (chapter.json mechanics.flood): the river's level, climate.flood 0–100.
## Every day it moves by the season's `flood_rise` (the Flood pushes it up, the other seasons
## let it fall). Above FLOOD_LINE the low ground (terrain FLOODPLAIN) is under water: every
## building standing there is wrecked that day unless it is `flood_proof` (stilts, piers,
## levees) or a working levee stands next to it. The Desk reads the level as stat_flood and
## the levees as stat_levees.

const FLOOD_LINE := 60.0
const MAX_LEVEL := 100.0
const DEFAULT_FALL := -5.0
const FLOODPLAIN := 8
const LEVEE := "bld_levee"


func process_tick() -> void:
	var climate: Dictionary = GameStateStore.climate()
	var day: int = climate.get("total_day", 1) as int
	if day <= (climate.get("flood_day", 0) as int):
		return
	climate["flood_day"] = day
	var rise: float = (climate.get("modifiers", {}) as Dictionary).get("flood_rise", DEFAULT_FALL) as float
	climate["flood"] = clampf((climate.get("flood", 0.0) as float) + rise, 0.0, MAX_LEVEL)
	if level() >= FLOOD_LINE:
		climate["flooded_today"] = flood_once()
	else:
		climate["flooded_today"] = 0


static func level() -> float:
	return GameStateStore.climate().get("flood", 0.0) as float


static func is_high() -> bool:
	return level() >= FLOOD_LINE


## Buildings on low ground that the water would take right now (what the HUD warns about).
static func exposed_coords() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		if is_exposed(coord):
			out.append(coord)
	return out


static func is_exposed(coord: Vector2i) -> bool:
	if GameStateStore.get_terrain(coord) != FLOODPLAIN:
		return false
	var bld: Dictionary = GameStateStore.get_building(coord)
	var type_id: String = bld.get("type", "") as String
	if type_id == "bld_road" or type_id == "road":
		return false
	var def: Dictionary = ContentDB.get_building_def(type_id)
	if (def.get("tags", []) as Array).has("flood_proof") or ContentDB.is_inert_landmark(type_id):
		return false
	return not has_levee(coord)


static func has_levee(coord: Vector2i) -> bool:
	for nb: Vector2i in HexCoords.neighbors_of(coord):
		if not GameStateStore.has_building(nb):
			continue
		var other: Dictionary = GameStateStore.get_building(nb)
		if other.get("type", "") == LEVEE and not (other.get("damaged", false) as bool):
			return true
	return false


static func levee_count() -> int:
	var count: int = 0
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		if GameStateStore.get_building(coord).get("type", "") == LEVEE:
			count += 1
	return count


## The water takes the exposed buildings; returns how many it took this time.
static func flood_once() -> int:
	var taken: int = 0
	for coord: Vector2i in exposed_coords():
		var bld: Dictionary = GameStateStore.get_building(coord)
		if bld.get("damaged", false) as bool:
			continue
		bld["damaged"] = true
		GameStateStore.set_building(coord, bld)
		EventBus.building_damaged.emit(coord, 1.0)
		taken += 1
	return taken
