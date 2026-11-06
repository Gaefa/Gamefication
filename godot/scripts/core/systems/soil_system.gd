class_name SoilSystem
## Chapter mechanic (chapter.json mechanics.soil): a plot's soil wears out. Every plot
## carries `soil` 0.3–1.0 and its food output is scaled by it. Plain ground loses a little
## every day, contested meadows do not (that is their temptation), the Rains season gives
## some back (`soil_recovery` modifier), and a seed vault within two hexes halves the loss.

const DAILY_LOSS := 0.015
const SOIL_FLOOR := 0.3
const VAULT_RADIUS := 2
const MEADOW := 6


func process_tick() -> void:
	var climate: Dictionary = GameStateStore.climate()
	var day: int = climate.get("total_day", 1) as int
	if day <= (climate.get("soil_day", 0) as int):
		return
	climate["soil_day"] = day
	var recovery: float = (climate.get("modifiers", {}) as Dictionary).get("soil_recovery", 0.0) as float
	var vaults: Array[Vector2i] = []
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		if GameStateStore.get_building(coord).get("type", "") == "bld_seed_vault":
			vaults.append(coord)
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var bld: Dictionary = GameStateStore.get_building(coord)
		var tags: Array = ContentDB.get_building_def(bld.get("type", "") as String).get("tags", []) as Array
		if not tags.has("food_source"):
			continue
		var soil: float = bld.get("soil", 1.0) as float
		var loss: float = 0.0 if GameStateStore.get_terrain(coord) == MEADOW else DAILY_LOSS
		if loss > 0.0 and vaults.any(func(v: Vector2i) -> bool: return HexCoords.distance(v, coord) <= VAULT_RADIUS):
			loss *= 0.5
		bld["soil"] = clampf(soil - loss + recovery, SOIL_FLOOR, 1.0)
		GameStateStore.set_building(coord, bld)
