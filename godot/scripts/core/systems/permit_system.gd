class_name PermitSystem
## Chapter mechanic (chapter.json mechanics.permits): the Directorate's building permits.
## climate.permits counts how many the district holds; every placed building spends one
## (roads and buildings tagged `no_permit` are free). The season's `permit_rate` adds a
## fraction every day (the Thaw's office works, the Audit's does not), the Desk's cards add
## or take whole permits (stat_permits), and the pile never grows past MAX_PERMITS.

const MAX_PERMITS := 6.0
const DEFAULT_RATE := 0.5


func process_tick() -> void:
	var climate: Dictionary = GameStateStore.climate()
	var day: int = climate.get("total_day", 1) as int
	if day <= (climate.get("permit_day", 0) as int):
		return
	if climate.get("permit_day", 0) as int > 0:  # the first day's permits are the chapter's starting pile
		var rate: float = (climate.get("modifiers", {}) as Dictionary).get("permit_rate", DEFAULT_RATE) as float + registry_rate()
		climate["permits"] = clampf((climate.get("permits", 0.0) as float) + rate, 0.0, MAX_PERMITS)
	climate["permit_day"] = day


static func enabled() -> bool:
	return (ContentDB.get_chapter_def().get("mechanics", {}) as Dictionary).get("permits", false) as bool


static func available() -> int:
	return int(floor(GameStateStore.climate().get("permits", 0.0) as float))


static func needs_permit(type_id: String) -> bool:
	if not enabled() or type_id == "bld_road" or type_id == "road":
		return false
	return not (ContentDB.get_building_def(type_id).get("tags", []) as Array).has("no_permit")


static func spend_one() -> void:
	var climate: Dictionary = GameStateStore.climate()
	climate["permits"] = maxf((climate.get("permits", 0.0) as float) - 1.0, 0.0)


## What the district's own offices add a day (buildings with `permit_rate`, while they work).
static func registry_rate() -> float:
	var total: float = 0.0
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var bld: Dictionary = GameStateStore.get_building(coord)
		if bld.get("damaged", false) as bool:
			continue
		total += ContentDB.get_building_def(bld.get("type", "") as String).get("permit_rate", 0.0) as float
	return total
