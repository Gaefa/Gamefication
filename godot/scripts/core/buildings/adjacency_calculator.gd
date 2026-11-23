class_name AdjacencyCalculator
## Neighbour rules between specific building pairs (GDD §16.2), from content/base/synergies.json.
##
## A rule names a pair [a, b] and what each side gets when the other stands next to it:
##   effects_a / effects_b   {res_id: bonus} added to that side's output (+0.1 = +10%)
##   mood_a / mood_b         happiness points for that side (housing by a quarry: −3)
##   full_pressure_a / _b    1 = that side always gets full water pressure
##   water_queue_a / _b      extra growth of the "water" pressure per such building
##   max_stack               how many neighbours of the other type count (default: all)
## Damaged buildings take no part in neighbour rules.
## Holds no game state: everything is read from GameStateStore, so it needs no save data.
## The one thing kept is which rules name a building type, which is content.

var _rules_of: Dictionary = {}  # type id → [[rule, side, other type, max_stack], …]
var _rules_source: Array = []   # the ContentDB.synergies array _rules_of was built from


func calculate_adjacency_bonus(coord: Vector2i, type_id: String) -> Dictionary:
	## Returns {resource_id: bonus_multiplier} from adjacent building synergies.
	var bonuses: Dictionary = {}
	for entry: Dictionary in active_rules(coord, type_id):
		var effects: Dictionary = (entry.rule as Dictionary).get("effects_" + (entry.side as String), {})
		for res_id: String in effects:
			bonuses[res_id] = (bonuses.get(res_id, 0.0) as float) + (effects[res_id] as float) * (entry.count as int)
	return bonuses


## Sum of a numeric rule field ("mood", "water_queue", "full_pressure") for this building.
func value_at(coord: Vector2i, type_id: String, key: String) -> float:
	var total: float = 0.0
	for entry: Dictionary in active_rules(coord, type_id):
		total += ((entry.rule as Dictionary).get("%s_%s" % [key, entry.side], 0.0) as float) * (entry.count as int)
	return total


## Rules currently in force for the building at coord: [{rule, side ("a"/"b"), count}].
## Called for every building on every tick, so a type no rule names costs one lookup.
func active_rules(coord: Vector2i, type_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var rules: Array = _rules_naming(type_id)
	if rules.is_empty():
		return result
	# A damaged building neither gets nor gives neighbour effects: it houses and produces nothing.
	if GameStateStore.get_building(coord).get("damaged", false) as bool:
		return result
	var near: Array[String] = []  # types of the neighbours that stand undamaged
	for nb: Vector2i in HexCoords.neighbors_of(coord):
		var nb_bld: Dictionary = GameStateStore.get_building(nb)
		if not nb_bld.is_empty() and not (nb_bld.get("damaged", false) as bool):
			near.append(nb_bld.get("type", "") as String)
	if near.is_empty():
		return result
	for named: Array in rules:
		var count: int = mini(near.count(named[2] as String), named[3] as int)
		if count > 0:
			result.append({ "rule": named[0], "side": named[1], "count": count })
	return result


func _rules_naming(type_id: String) -> Array:
	if not is_same(_rules_source, ContentDB.synergies):
		_rules_source = ContentDB.synergies
		_rules_of.clear()
	if not _rules_of.has(type_id):
		var found: Array = []
		for syn: Dictionary in ContentDB.synergies:
			var side: String = _side_of(syn, type_id)
			if side != "":
				found.append([syn, side, (syn.get("pair", []) as Array)[1 if side == "a" else 0] as String, syn.get("max_stack", 6) as int])
		_rules_of[type_id] = found
	return _rules_of[type_id] as Array


## Rules that could apply to this building type — shown when the player picks it to build.
func rules_for_type(type_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for syn: Dictionary in ContentDB.synergies:
		if _side_of(syn, type_id) != "":
			result.append(syn)
	return result


func _side_of(syn: Dictionary, type_id: String) -> String:
	var pair: Array = syn.get("pair", [])
	if pair.size() != 2:
		return ""
	if type_id == (pair[0] as String):
		return "a"
	if type_id == (pair[1] as String):
		return "b"
	return ""
