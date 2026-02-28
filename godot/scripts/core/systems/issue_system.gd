class_name IssueSystem
## Randomly spawns issues on buildings each tick (small chance).
## Issues reduce building output; repair command fixes them.

var _rng: SeededRNG

const ISSUE_CHANCE_PER_BUILDING := 0.001  # 0.1% per tick per building


func _init(rng: SeededRNG) -> void:
	_rng = rng


func process_tick() -> void:
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var bld: Dictionary = GameStateStore.get_building(coord)
		if bld.get("has_issue", false) as bool:
			continue
		if bld.get("damaged", false) as bool:
			continue
		var type_id: String = bld.get("type", "") as String
		if type_id == "road":
			continue
		if _rng.chance(ISSUE_CHANCE_PER_BUILDING):
			bld["has_issue"] = true
			GameStateStore.set_building(coord, bld)
