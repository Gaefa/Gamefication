class_name WasteSystem
## Chapter mechanic (chapter.json mechanics.waste): the district's smoke and slag as one
## number, climate.waste 0–100. Every day the working polluters add their `waste_per_day`
## (times the season's `waste_mult`), the working, powered cleaners take their `waste_sink`,
## and the air clears a little on its own. ProgressionSystem turns the level into a mood
## term; the Desk's cards read it as stat_waste and move it with the same key.

const NATURAL_CLEARING := 1.0
const MAX_WASTE := 100.0
const MOOD_PER_POINT := 0.25  # 40 waste is -10 mood, the whole scale -25


func process_tick() -> void:
	var climate: Dictionary = GameStateStore.climate()
	var day: int = climate.get("total_day", 1) as int
	if day <= (climate.get("waste_day", 0) as int):
		return
	climate["waste_day"] = day
	var mult: float = (climate.get("modifiers", {}) as Dictionary).get("waste_mult", 1.0) as float
	var waste: float = climate.get("waste", 0.0) as float
	waste += daily_gain() * mult - daily_sink() - NATURAL_CLEARING
	climate["waste"] = clampf(waste, 0.0, MAX_WASTE)


static func level() -> float:
	return GameStateStore.climate().get("waste", 0.0) as float


static func mood_term() -> float:
	return -level() * MOOD_PER_POINT


## What the working pits and furnaces put out in a day, before the season's multiplier.
static func daily_gain() -> float:
	var total: float = 0.0
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var bld: Dictionary = GameStateStore.get_building(coord)
		if bld.get("damaged", false) as bool:
			continue
		total += ContentDB.get_building_def(bld.get("type", "") as String).get("waste_per_day", 0.0) as float
	return total


## What the filters and heaps take back in a day; a filter without power is a shed.
static func daily_sink() -> float:
	var total: float = 0.0
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var bld: Dictionary = GameStateStore.get_building(coord)
		if (bld.get("damaged", false) as bool) or not (bld.get("powered", true) as bool):
			continue
		total += ContentDB.get_building_def(bld.get("type", "") as String).get("waste_sink", 0.0) as float
	return total
