class_name SeasonSystem
## Climate axis (GDD §14). Drives the Окно → Пыль cycle.
##
## Source of truth is GameStateStore.climate():
##   season_id, season_index, day_in_season, total_day, modifiers.
##
## A game day elapses when SimulationRunner.day_count increments (once per full
## День → Вечер → Утро cycle). On each elapsed day we advance day_in_season and,
## at the season boundary, switch to the next season in ContentDB.season_order
## (wrapping around — the tail of Пыль loops back into a new Окно).
##
## Active season modifiers are written into climate().modifiers; EconomySystem
## reads them to make Пыль cost more water and yield less food.

var _order: Array = []
## Last game day this system has already processed. Kept in lockstep with
## SimulationRunner.day_count so reloads and pauses can't double-advance.
var _processed_day: int = 0


func initialize() -> void:
	_order = ContentDB.get_season_order()
	if _order.is_empty():
		push_warning("SeasonSystem: no seasons defined; climate disabled.")
		return

	var climate: Dictionary = GameStateStore.climate()
	# Fresh game (no season assigned yet) → start at the first season, day 1.
	if (climate.get("season_id", "") as String) == "":
		climate["season_index"] = 0
		climate["day_in_season"] = 1
		climate["total_day"] = 1
	climate["season_index"] = clampi(climate.get("season_index", 0) as int, 0, _order.size() - 1)

	_processed_day = maxi(climate.get("total_day", 1) as int, 1)
	# Re-sync the runtime day counter so a loaded save resumes on the right day.
	SimulationRunner.day_count = _processed_day
	_apply_current(true)


func process_tick() -> void:
	if _order.is_empty():
		return
	var day: int = SimulationRunner.day_count
	# Advance one game-day at a time so no boundary is skipped.
	while _processed_day < day:
		_processed_day += 1
		_advance_one_day()


func _advance_one_day() -> void:
	var climate: Dictionary = GameStateStore.climate()
	var idx: int = climate.get("season_index", 0) as int
	var current_def: Dictionary = ContentDB.get_season_def(_order[idx] as String)
	var length: int = maxi(current_def.get("length_days", 15) as int, 1)
	var next_day_in_season: int = (climate.get("day_in_season", 1) as int) + 1

	climate["total_day"] = _processed_day

	if next_day_in_season > length:
		# Boundary: roll over to the next season (wrap to the start).
		idx = (idx + 1) % _order.size()
		climate["season_index"] = idx
		climate["day_in_season"] = 1
		_apply_current(true)
	else:
		climate["day_in_season"] = next_day_in_season
		_apply_current(false)


func _apply_current(is_new_season: bool) -> void:
	var climate: Dictionary = GameStateStore.climate()
	var idx: int = climate.get("season_index", 0) as int
	var season_id: String = _order[idx] as String
	var def: Dictionary = ContentDB.get_season_def(season_id)
	var length: int = maxi(def.get("length_days", 15) as int, 1)
	var day_in_season: int = climate.get("day_in_season", 1) as int

	climate["season_id"] = season_id
	climate["modifiers"] = (def.get("modifiers", {}) as Dictionary).duplicate(true)

	if is_new_season:
		EventBus.season_changed.emit(season_id, day_in_season, length)
	EventBus.season_day_advanced.emit(season_id, day_in_season, length)


# --- Queries (used by UI/forecast) ---

func current_season_id() -> String:
	return GameStateStore.climate().get("season_id", "") as String


func days_left_in_season() -> int:
	var climate: Dictionary = GameStateStore.climate()
	var def: Dictionary = ContentDB.get_season_def(climate.get("season_id", "") as String)
	var length: int = maxi(def.get("length_days", 15) as int, 1)
	return maxi(length - (climate.get("day_in_season", 1) as int), 0)


func next_season_id() -> String:
	if _order.is_empty():
		return ""
	var idx: int = GameStateStore.climate().get("season_index", 0) as int
	return _order[(idx + 1) % _order.size()] as String
