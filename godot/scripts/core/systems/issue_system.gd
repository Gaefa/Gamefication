class_name IssueSystem
## Randomly spawns issues on buildings each tick (small chance).
## Issues reduce building output; repair command fixes them.

var _rng: SeededRNG

## 0.04% per tick: a building breaks about every eight days, so a starter district (eight
## things that can break) sees roughly one "!" a day and a 16-building district two. At the
## old 0.1% the repairs (10 money each) ate 24–50 money a day, as much as the shelters earned.
const ISSUE_CHANCE_PER_BUILDING := 0.0004


func _init(rng: SeededRNG) -> void:
	_rng = rng


## What can break and so what the bookkeeper keeps a repair reserve for: everything but
## roads, ruins and monuments. The tick loop below applies the same rule.
static func breakable_buildings() -> int:
	var count: int = 0
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var type_id: String = GameStateStore.get_building(coord).get("type", "") as String
		if type_id == "road" or type_id == "bld_road" or ContentDB.is_inert_landmark(type_id):
			continue
		count += 1
	return count


func process_tick() -> void:
	# The Dust clogs machinery: the season's wear_mult scales the breakdown chance.
	var wear: float = (GameStateStore.climate().get("modifiers", {}) as Dictionary).get("wear_mult", 1.0) as float
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var bld: Dictionary = GameStateStore.get_building(coord)
		if bld.get("has_issue", false) as bool:
			continue
		if bld.get("damaged", false) as bool:
			continue
		var type_id: String = bld.get("type", "") as String
		if type_id == "road" or type_id == "bld_road":
			continue
		if ContentDB.is_inert_landmark(type_id):
			continue  # ruins and monuments have nothing to break and nothing to repair
		if _rng.chance(ISSUE_CHANCE_PER_BUILDING * wear):
			bld["has_issue"] = true
			GameStateStore.set_building(coord, bld)
			EventBus.building_issue_added.emit(coord)
	# Mirror the random sequence into the save so a load continues it exactly.
	GameStateStore.save_meta().rng_state = _rng.get_state()
