class_name PressureSystem
## Pressure director (GDD §15): an honest counter — not an AI, not dice.
## Four categories — food, water, happiness (people), mandate — each accumulate
## points while their risk is present and drain while it isn't. When a category
## fills it raises pressure_threshold_reached(category); EventManager turns that
## into a crisis of that category. The category then drops back only partway:
## the root cause keeps pushing, so treating the symptom only delays the next one.
##
## `index` (the fullest category) and `phase` stay for existing readers.

const THRESHOLD := 100.0
const RESET_TO := 40.0          # partial reset after a crisis fires (§15.3)
const GAIN_PER_TICK := 0.15     # at full risk a category fills in ~2 days, ~1.5 in Пыль (tuning)
const DECAY_PER_TICK := 0.08    # drains once the risk is gone (tuning)

const FOOD_SAFE := 60.0         # reserves/levels below these start to build pressure
const WATER_SAFE := 150.0
const HAPPINESS_SAFE := 45.0
const TRUST_SAFE := 50.0

const CATEGORIES := ["food", "water", "happiness", "mandate"]


func process_tick() -> void:
	var pressure_state: Dictionary = GameStateStore.pressure()
	var cats: Dictionary = pressure_state.get("categories", {}) as Dictionary
	pressure_state.categories = cats
	var amplify: Dictionary = ContentDB.get_season_def(GameStateStore.climate().get("season_id", "") as String).get("pressure_amplify", {})
	var gov: float = _governance_factor()
	var risks := {
		"food": _below(GameStateStore.get_resource("res_food"), FOOD_SAFE),
		"water": _below(GameStateStore.get_resource("res_water_stockpile"), WATER_SAFE),
		"happiness": _below(GameStateStore.population().get("happiness", 50.0) as float, HAPPINESS_SAFE),
		"mandate": _below(GameStateStore.mandate().get("patron_trust", 50) as float, TRUST_SAFE),
	}
	if (GameStateStore.mandate().get("patron_id", "") as String) == "":
		risks["mandate"] = 0.0  # a founder answers to no patron

	var top: float = 0.0
	for cat: String in CATEGORIES:
		var value: float = cats.get(cat, 0.0) as float
		var risk: float = risks[cat] as float
		if risk > 0.0:
			var gain: float = GAIN_PER_TICK * risk * gov
			gain *= amplify.get(cat, 1.0) as float
			if cat == "water":
				gain *= 1.0 + _water_queue()
			value += gain
		else:
			value -= DECAY_PER_TICK
		value = clampf(value, 0.0, THRESHOLD)
		cats[cat] = value
		if value >= THRESHOLD:
			# Stays full (and keeps signalling) until a crisis actually lands — the handler
			# drops it back to RESET_TO. If every crisis of the category is cooling down,
			# the pressure waits at the top instead of being silently absorbed.
			EventBus.pressure_threshold_reached.emit(cat)
		top = maxf(top, cats[cat] as float)

	pressure_state.index = top
	pressure_state.phase = _index_to_phase(top)
	EventBus.pressure_updated.emit(top, pressure_state.phase as String)


func _below(value: float, safe: float) -> float:
	## 0 when at/above the safe level, rising to 1 at zero.
	return clampf((safe - value) / safe, 0.0, 1.0)


func _index_to_phase(index: float) -> String:
	if index < 25.0:
		return "calm"
	elif index < 50.0:
		return "tension"
	elif index < 75.0:
		return "crisis"
	else:
		return "emergency"


## Housing crowding the Cistern makes the queue there worse (synergies.json: water_queue).
func _water_queue() -> float:
	var adjacency := AdjacencyCalculator.new()
	var total: float = 0.0
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		total += adjacency.value_at(coord, GameStateStore.get_building(coord).get("type", "") as String, "water_queue")
	return total


func _governance_factor() -> float:
	## Technologies, policies and the start profile tune how fast pressure builds.
	var delta := 0.0
	var mult := 1.0
	for tech_var: Variant in GameStateStore.get_technologies():
		var tech_def: Dictionary = ContentDB.get_technology_def(tech_var as String)
		var effects: Dictionary = tech_def.get("effects", {})
		delta += effects.get("pressure_delta", 0.0) as float
		mult *= effects.get("pressure_mult", 1.0) as float
	for policy_var: Variant in GameStateStore.get_active_policies().values():
		var policy_def: Dictionary = ContentDB.get_policy_def(policy_var as String)
		var effects: Dictionary = policy_def.get("effects", {})
		delta += effects.get("pressure_delta", 0.0) as float
		mult *= effects.get("pressure_mult", 1.0) as float
	var mandate_effects: Dictionary = GameStateStore.mandate().get("effects", {})
	delta += mandate_effects.get("pressure_delta", 0.0) as float
	mult *= mandate_effects.get("pressure_mult", 1.0) as float
	return maxf(mult * (1.0 + delta / 100.0), 0.0)
