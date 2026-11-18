extends "res://tools/loop_smoke.gd"
## A player who builds. loop_smoke's auto-player only answers the Desk and repairs, so its
## districts never grow and every chapter ends "not renewed". This one plays the day too:
## water, food, power, materials, housing, and the chapter's own threat (levees against the
## river, filters against the smoke, a registry for permits). At the Desk it weighs what
## every answer does to trust, support, stock and people instead of taking the first one.
##
## It answers one question per chapter: can a careful player win it, and by what margin.
## It is a plain greedy player, not an optimiser: when it loses, read why before blaming it.
##
## Run: Godot --headless --fixed-fps 60 --path <proj> res://tools/player_bot.tscn --quit-after 400000 -- chapter=<id> [seed=N] [lean=patron|city] [pace=N] [verbose]
## pace is decisions a day (default 30): pace=1 is a player who does one thing a day.
## Dev tool, not shipped.

const FRAMES_PER_DAY := 60      # at loop_smoke's speed
const TARGET_BEDS := 20         # the win asks for twelve people; aim past it
const MONEY_FLOOR := 25.0       # never spend the treasury below this
const PER_DAY := 2               # of one building type a day (roads: three times that): a new pump needs a day to show in the stores
const RES_VALUE := {"res_money": 1.0, "res_food": 1.0, "res_water_stockpile": 1.0, "res_wood": 1.5, "res_stone": 1.5, "res_tools": 8.0, "res_metal": 4.0}

var _lean: String = ""
var _step_every: int = 2        # sim frames between two decisions: thirty decisions a day
var _verbose: bool = false
var _bot_seed: int = 12345
var _frame: int = 0
var _built: Dictionary = {}     # type id → how many the bot placed
var _built_today: Dictionary = {}  # type id → how many since the last evening
var _upgrades: int = 0
var _salvaged: int = 0
var _net: Dictionary = {}       # res id → smoothed net per day
var _day_twelve: int = -1       # the first day the district held twelve people
var _hungry_evenings: int = 0
var _dry_evenings: int = 0
var _low_mood_evenings: int = 0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("lean="):
			_lean = arg.trim_prefix("lean=")
		elif arg.begins_with("seed="):
			_bot_seed = arg.trim_prefix("seed=").to_int()
		elif arg.begins_with("pace="):
			_step_every = maxi(1, FRAMES_PER_DAY / maxi(1, arg.trim_prefix("pace=").to_int()))
		elif arg == "verbose":
			_verbose = true
	EventBus.evening_started.connect(func(_events: Array) -> void:
		_built_today.clear()
		var pop: Dictionary = GameStateStore.population()
		if _day_twelve < 0 and (pop.get("total", 0) as int) >= EndingManager.WIN_PEOPLE:
			_day_twelve = SimulationRunner.day_count
		if GameStateStore.get_resource("res_food") <= 0.0:
			_hungry_evenings += 1
		if GameStateStore.get_resource("res_water_stockpile") <= 0.0:
			_dry_evenings += 1
		if (pop.get("happiness", 50.0) as float) < EndingManager.WIN_HAPPINESS:
			_low_mood_evenings += 1)
	super._ready()


func _attach() -> void:
	super._attach()
	seed(_bot_seed)  # the issue and card sequence of this run


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _desk == null or _ending != "" or _desk.visible or SimulationRunner.paused or not SimulationRunner.run_active:
		return
	_frame += 1
	_sample_flows()
	if _frame % _step_every == 0:
		_bot_step()


# --- the day -------------------------------------------------------------------------------

func _orch() -> GameOrchestrator:
	return _main.call("get_orchestrator") as GameOrchestrator


func _sample_flows() -> void:
	var prod: Dictionary = GameStateStore.economy().get("production", {}) as Dictionary
	for res_id: String in prod:
		var per_day: float = (prod[res_id] as float) * float(SimulationRunner.TICKS_PER_DAY)
		_net[res_id] = lerpf(_net.get(res_id, per_day) as float, per_day, 0.1)


func _flow(res_id: String) -> float:
	return _net.get(res_id, 0.0) as float


func _bot_step() -> void:
	var orch: GameOrchestrator = _orch()
	if orch == null:
		return
	orch.coverage.ensure_fresh()
	var pop: Dictionary = GameStateStore.population()
	var total: int = pop.get("total", 0) as int
	var served: int = pop.get("served", 0) as int
	var capacity: int = pop.get("capacity", 0) as int
	var happiness: float = pop.get("happiness", 50.0) as float
	var power: Dictionary = GameStateStore.power()

	if _frame < 10:
		return  # the first ticks have no flows to read yet
	_repair_now()
	# Stone and wood before anything that spends them: with no quarry the first pump
	# upgrade eats the last stone, and then there is no road to put a quarry by.
	if _restock("res_stone", 25.0, "bld_quarry_pit") or _restock("res_wood", 30.0, "bld_lumber_yard"):
		return
	if _answer_chapter_threat() or _keep_street_open():
		return
	# Water and food first: a district that grows past them empties in two days.
	var water_short: bool = _running_out("res_water_stockpile")
	var food_short: bool = _running_out("res_food")
	if water_short and (_upgrade_tagged("water_source") or _upgrade_tagged("water_storage") or _place_scored("bld_well_pump")):
		return
	if food_short and (_place_food() or _upgrade_tagged("food_source")):
		return
	# Panels cost nothing to run; a generator burns money every day, so only on a healthy income.
	if (power.get("demand", 0.0) as float) > (power.get("generation", 0.0) as float):
		if _place_scored("bld_solar_panel") or (_flow("res_money") > 30.0 and _place_scored("bld_generator")):
			return
	if _ease_weak_pressure():
		return
	if GameStateStore.get_resource("res_tools") < 3.0 and _count("bld_tool_workshop") == 0 and _place_scored("bld_tool_workshop"):
		return
	if ContentDB.get_resource_ids().has("res_metal") and GameStateStore.get_resource("res_metal") < 15.0:
		if _salvage_ruin() or (_count("bld_ore_pit") == 0 and _place_scored("bld_ore_pit")):
			return
	# Grow while people are content, the beds are full, and the stores can carry one more house.
	var beds_full: bool = total >= served - 1
	if beds_full and capacity < TARGET_BEDS and happiness >= 45.0:
		if not _plenty("res_water_stockpile"):
			if _upgrade_tagged("water_source") or _place_scored("bld_well_pump"):
				return
		elif not _plenty("res_food"):
			if _place_food() or _upgrade_tagged("food_source"):
				return
		elif _place_housing() or _upgrade_tagged("housing"):
			return
	# Housing that stands unserved (no water, no road) is the usual reason beds stay empty.
	if served < capacity and _serve_housing():
		return
	if GameStateStore.get_resource("res_money") > 150.0:
		if _upgrade_tagged("housing") or _upgrade_tagged("food_source") or _upgrade_tagged("water_source"):
			return


## Short when the store lasts under three days at today's draw, or is draining toward
## empty within six (the Dust empties a full cistern in a week).
func _running_out(res_id: String) -> bool:
	if EconomySystem.days_of(res_id) < 3.0:
		return true
	var flow: float = _flow(res_id)
	return flow < 0.0 and GameStateStore.get_resource(res_id) / -flow < 6.0


## Enough to carry one more house: the store is near its cap (a full store reads as zero
## net flow, which is not a shortage) or it is still filling by a house's worth a day.
func _plenty(res_id: String) -> bool:
	var cap: float = GameStateStore.get_cap(res_id)
	return (cap > 0.0 and GameStateStore.get_resource(res_id) >= cap * 0.85) or _flow(res_id) >= 40.0


## Houses at the far end of an overloaded pump grumble: give them a pump of their own.
func _ease_weak_pressure() -> bool:
	if (GameStateStore.population().get("low_pressure_housing", 0) as int) <= 0:
		return false
	var orch: GameOrchestrator = _orch()
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var bld: Dictionary = GameStateStore.get_building(coord)
		if (ContentDB.building_level_data(bld.get("type", "") as String, bld.get("level", 0) as int).get("population", 0) as int) <= 0:
			continue
		if orch.coverage.is_water_covered(coord) and orch.coverage.water_pressure(coord) < ProgressionSystem.WEAK_PRESSURE:
			return _upgrade_tagged("water_source") or _place_scored("bld_well_pump", coord)
	return false


## A player repairs when the pin appears, not at dusk; housing first, people leave a broken house.
func _repair_now() -> void:
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var bld: Dictionary = GameStateStore.get_building(coord)
		if (bld.get("damaged", false) as bool) or (bld.get("has_issue", false) as bool):
			_orch().command_bus.execute(RepairBuildingCommand.new(coord))


## Every building wants a road at its side, and a road grows only from a road. Keep two
## free cells by the street, or the district walls its own streets in.
func _keep_street_open() -> bool:
	var orch: GameOrchestrator = _orch()
	var open_cells: int = 0
	for cell: Vector2i in _frontier():
		if _by_road(cell) and orch.hex_grid.is_valid(cell) and (ContentDB.get_terrain_def(GameStateStore.get_terrain(cell)).get("buildable", true) as bool):
			open_cells += 1
	return open_cells <= 2 and _extend_road(false)


## Levees by buildings the river reaches, filters and heaps against smoke, a registry for permits.
func _answer_chapter_threat() -> bool:
	var mechanics: Dictionary = ContentDB.get_chapter_def().get("mechanics", {}) as Dictionary
	if mechanics.get("flood", false) as bool:
		for coord: Vector2i in FloodSystem.exposed_coords():
			for nb: Vector2i in HexCoords.neighbors_of(coord):
				if _place("bld_levee", nb):
					return true
	if mechanics.get("waste", false) as bool:
		if WasteSystem.level() > 20.0 and WasteSystem.daily_gain() > WasteSystem.daily_sink() + WasteSystem.NATURAL_CLEARING:
			if _place_scored("bld_filter_station") or _place_scored("bld_slag_heap"):
				return true
	if PermitSystem.enabled() and _count("bld_registry") == 0 and _place_scored("bld_registry"):
		return true
	return false


func _restock(res_id: String, floor_stock: float, producer: String) -> bool:
	if GameStateStore.get_resource(res_id) >= floor_stock or _flow(res_id) > 0.5 or _count(producer) > 0:
		return false
	if _place_scored(producer):
		return true
	# No road to put it by and no stone for a road: off the road it still works at a third.
	var orch: GameOrchestrator = _orch()
	for cell: Vector2i in _frontier():
		if (PlacementRules.validate(cell, producer, orch.hex_grid).get("ok", false) as bool) and _place(producer, cell):
			return true
	return false


func _place_food() -> bool:
	var best_type: String = ""
	var best_cell := Vector2i.ZERO
	var best_score: float = -INF
	for type_id: String in ContentDB.get_building_ids():
		var def: Dictionary = ContentDB.get_building_def(type_id)
		if not (def.get("tags", []) as Array).has("food_source") or not (def.get("player_buildable", true) as bool):
			continue
		var found: Dictionary = _best_cell(type_id)
		if found.is_empty():
			continue
		# A pier needs no water; a field drinks. Prefer whatever the land favours.
		var score: float = (found["score"] as float) + (0.2 if (ContentDB.building_level_data(type_id, 0).get("consumes", {}) as Dictionary).is_empty() else 0.0)
		if score > best_score:
			best_score = score
			best_type = type_id
			best_cell = found["cell"] as Vector2i
	return best_type != "" and _place(best_type, best_cell)


func _place_housing() -> bool:
	var best_type: String = ""
	var best_cell := Vector2i.ZERO
	var best_score: float = -INF
	for type_id: String in ContentDB.get_building_ids():
		var def: Dictionary = ContentDB.get_building_def(type_id)
		if not (def.get("tags", []) as Array).has("housing") or not (def.get("player_buildable", true) as bool):
			continue
		var found: Dictionary = _best_cell(type_id)
		if found.is_empty():
			continue
		var score: float = float(ContentDB.building_level_data(type_id, 0).get("population", 0) as int) + (found["score"] as float)
		if score > best_score:
			best_score = score
			best_type = type_id
			best_cell = found["cell"] as Vector2i
	if best_type != "":
		return _place(best_type, best_cell)
	# Nowhere to put a house: no served cell is free. Lay a road toward watered ground,
	# or bring water to ground the roads already reach.
	return _extend_road(true) or _place_scored("bld_well_pump")


## Beds that nobody can use: bring the road or the water to them.
func _serve_housing() -> bool:
	var orch: GameOrchestrator = _orch()
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var bld: Dictionary = GameStateStore.get_building(coord)
		if (ContentDB.building_level_data(bld.get("type", "") as String, bld.get("level", 0) as int).get("population", 0) as int) <= 0:
			continue
		if not orch.coverage.is_water_covered(coord):
			return _place_scored("bld_well_pump", coord)
		if orch.coverage.road_efficiency(coord) < 1.0:
			for nb: Vector2i in HexCoords.neighbors_of(coord):
				if _place("bld_road", nb):
					return true
	return false


func _place_scored(type_id: String, near: Vector2i = Vector2i(-9999, -9999)) -> bool:
	if ContentDB.get_building_def(type_id).is_empty():
		return false
	var def: Dictionary = ContentDB.get_building_def(type_id)
	if not _can_pay(PlacementRules.build_cost_for(def)):
		return false
	var found: Dictionary = _best_cell(type_id, near)
	if not found.is_empty():
		return _place(type_id, found["cell"] as Vector2i)
	# Affordable, and no cell by a road is free: the district has outgrown its streets.
	return (def.get("tags", []) as Array).has("needs_road") and _extend_road(false)


## The best free cell for a building: valid, served the way the building needs, on the
## terrain that suits it, out of the river's reach unless the building stands the water.
func _best_cell(type_id: String, near: Vector2i = Vector2i(-9999, -9999)) -> Dictionary:
	var orch: GameOrchestrator = _orch()
	var def: Dictionary = ContentDB.get_building_def(type_id)
	var tags: Array = def.get("tags", []) as Array
	if not _can_pay(PlacementRules.build_cost_for(def)):
		return {}
	var bonuses: Dictionary = def.get("terrain_bonus", {}) as Dictionary
	var needs_road: bool = tags.has("needs_road")
	var is_housing: bool = tags.has("housing")
	var is_pump: bool = tags.has("water_source")
	var best: Dictionary = {}
	for cell: Vector2i in _frontier():
		if not (PlacementRules.validate(cell, type_id, orch.hex_grid).get("ok", false) as bool):
			continue
		if needs_road and not _by_road(cell):
			continue
		var terrain: int = GameStateStore.get_terrain(cell)
		if terrain == FloodSystem.FLOODPLAIN and not tags.has("flood_proof") and not tags.has("food_source"):
			continue
		if is_housing and not orch.coverage.is_water_covered(cell):
			continue
		var score: float = bonuses.get(str(terrain), 0.0) as float
		if is_pump:
			# A new pump earns its keep where water does not reach yet.
			score += 0.5 if not orch.coverage.is_water_covered(cell) else 0.0
		if near.x != -9999:
			score -= 0.1 * float(HexCoords.distance(cell, near))
		if best.is_empty() or score > (best["score"] as float):
			best = {"cell": cell, "score": score}
	return best


## A road cell that opens the most free ground (watered ground when it is for housing).
func _extend_road(watered: bool) -> bool:
	var orch: GameOrchestrator = _orch()
	var best := Vector2i(-9999, -9999)
	var best_gain: int = 0
	for cell: Vector2i in _frontier():
		if not _by_road(cell) or not (PlacementRules.validate(cell, "bld_road", orch.hex_grid).get("ok", false) as bool):
			continue
		var gain: int = 0
		for nb: Vector2i in HexCoords.neighbors_of(cell):
			if not GameStateStore.has_building(nb) and not _by_road(nb) and orch.hex_grid.is_valid(nb) \
					and (not watered or orch.coverage.is_water_covered(nb)) \
					and (ContentDB.get_terrain_def(GameStateStore.get_terrain(nb)).get("buildable", true) as bool):
				gain += 1
		if gain > best_gain:
			best_gain = gain
			best = cell
	return best_gain > 0 and _place("bld_road", best)


## Free cells within two steps of anything built: where a district grows.
func _frontier() -> Array[Vector2i]:
	var seen: Dictionary = {}
	var out: Array[Vector2i] = []
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		for cell: Vector2i in HexCoords.disk(coord, 2):
			if not seen.has(cell) and not GameStateStore.has_building(cell):
				seen[cell] = true
				out.append(cell)
	return out


func _by_road(cell: Vector2i) -> bool:
	for nb: Vector2i in HexCoords.neighbors_of(cell):
		if (GameStateStore.get_building(nb).get("type", "") as String) == "bld_road":
			return true
	return false


func _can_pay(cost: Dictionary) -> bool:
	if not GameStateStore.can_afford(cost):
		return false
	return not cost.has("res_money") or GameStateStore.get_resource("res_money") - (cost["res_money"] as float) >= MONEY_FLOOR


func _place(type_id: String, cell: Vector2i) -> bool:
	if ContentDB.get_building_def(type_id).is_empty() or not _can_pay(PlacementRules.build_cost_for(ContentDB.get_building_def(type_id))):
		return false
	if (_built_today.get(type_id, 0) as int) >= PER_DAY * (3 if type_id == "bld_road" else 1):
		return false
	var command := PlaceBuildingCommand.new(cell, type_id)
	_orch().command_bus.execute(command)
	if command.success:
		_built[type_id] = (_built.get(type_id, 0) as int) + 1
		_built_today[type_id] = (_built_today.get(type_id, 0) as int) + 1
		if _verbose:
			print("    бот, день %d: строит %s на %s" % [SimulationRunner.day_count, type_id, str(cell)])
	return command.success


func _upgrade_tagged(tag: String) -> bool:
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var bld: Dictionary = GameStateStore.get_building(coord)
		var type_id: String = bld.get("type", "") as String
		if not (ContentDB.get_building_def(type_id).get("tags", []) as Array).has(tag):
			continue
		if (bld.get("level", 0) as int) + 1 >= ContentDB.max_building_level(type_id):
			continue
		var cost: Dictionary = ContentDB.building_level_data(type_id, (bld.get("level", 0) as int) + 1).get("cost", {}) as Dictionary
		if not _can_pay(cost):
			continue
		var command := UpgradeBuildingCommand.new(coord)
		_orch().command_bus.execute(command)
		if command.success:
			_upgrades += 1
			if _verbose:
				print("    бот, день %d: улучшает %s на %s" % [SimulationRunner.day_count, type_id, str(coord)])
			return true
	return false


func _salvage_ruin() -> bool:
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var def: Dictionary = ContentDB.get_building_def(GameStateStore.get_building(coord).get("type", "") as String)
		if def.has("salvage"):
			var command := BulldozeCommand.new(coord)
			_orch().command_bus.execute(command)
			if command.success:
				_salvaged += 1
				return true
	return false


func _count(type_id: String) -> int:
	var n: int = 0
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		if (GameStateStore.get_building(coord).get("type", "") as String) == type_id:
			n += 1
	return n


# --- the Desk ------------------------------------------------------------------------------

func _auto_resolve() -> void:
	if (_desk.get("_finish_btn") as Button).visible or (_desk.get("_next_btn") as Button).visible:
		super._auto_resolve()
		return
	var events: Array = _desk.get("_events") as Array
	var idx: int = _desk.get("_current_index") as int
	if idx >= events.size():
		return
	var evt: Dictionary = events[idx] as Dictionary
	var options: Array = evt.get("options", []) as Array
	if options.is_empty():
		return
	var pick: int = -1
	var best: float = -INF
	for i: int in options.size():
		var option: Dictionary = options[i] as Dictionary
		var cost: Dictionary = option.get("cost", {}) as Dictionary
		if not cost.is_empty() and not GameStateStore.can_afford(cost):
			continue
		var score: float = _option_score(option.get("effects", {}) as Dictionary, cost)
		if score > best:
			best = score
			pick = i
	if pick < 0:
		pick = 0
	var opt: Dictionary = options[pick] as Dictionary
	_cards += 1
	print("    день %d: %s → «%s» (вес %.1f)" % [SimulationRunner.day_count, evt.get("runtime_id", "?") as String, (opt.get("text", "?") as String).left(40), best])
	_desk.call("_select_option", evt.get("runtime_id", "") as String, pick, opt.get("effects", {}), opt.get("cost", {}))


## What an answer is worth: trust and support weigh more the closer they stand to zero
## (both at zero end the run), then people, stock, damage and the chapter's own gauges.
func _option_score(effects: Dictionary, cost: Dictionary) -> float:
	var mandate: Dictionary = GameStateStore.mandate()
	var trust: float = mandate.get("patron_trust", 50) as float
	var support: float = mandate.get("support", 50) as float
	var d_trust: float = effects.get("stat_league_trust", 0.0) as float
	var d_support: float = effects.get("stat_city_trust", 0.0) as float
	var score: float = d_trust * _need_weight(trust) * (1.5 if _lean == "patron" else 1.0) \
		+ d_support * _need_weight(support) * (1.5 if _lean == "city" else 1.0)
	if trust + d_trust <= 8.0 or support + d_support <= 8.0:
		score -= 100.0  # one step from recall or riot
	score -= 0.5 * (effects.get("stat_unrest_pressure", 0.0) as float)
	score -= 0.3 * (effects.get("stat_rival_score", 0.0) as float)
	score += 4.0 * (effects.get("add_residents", 0.0) as float)
	score += 4.0 * (effects.get("stat_permits", 0.0) as float)
	score -= 0.5 * (effects.get("stat_waste", 0.0) as float)
	score -= 0.3 * (effects.get("stat_flood", 0.0) as float)
	for key: String in ["damage_building", "damage_buildings", "demolish_building", "force_issues"]:
		if effects.has(key):
			score -= 8.0
	var gains: Dictionary = effects.get("add_resources", {}) as Dictionary
	for res_id: String in gains:
		score += 0.1 * (gains[res_id] as float) * (RES_VALUE.get(res_id, 1.0) as float)
	for res_id: String in cost:
		# A price paid out of a thin store hurts more than its face value.
		var thin: float = 3.0 if GameStateStore.get_resource(res_id) - (cost[res_id] as float) < 20.0 else 1.0
		score -= 0.1 * (cost[res_id] as float) * (RES_VALUE.get(res_id, 1.0) as float) * thin
	var buff: Dictionary = effects.get("add_buff", {}) as Dictionary
	score += 0.3 * (buff.get("happiness_add", 0.0) as float)
	return score


func _need_weight(value: float) -> float:
	return 2.5 if value < 30.0 else (1.0 if value < 60.0 else 0.4)


# --- the verdict ---------------------------------------------------------------------------

func _finish(result: String) -> void:
	print(_summary(result))
	super._finish(result)


func _summary(result: String) -> String:
	var pop: Dictionary = GameStateStore.population()
	var mandate: Dictionary = GameStateStore.mandate()
	var built: Array[String] = []
	for type_id: String in _built:
		built.append("%s×%d" % [type_id.trim_prefix("bld_"), _built[type_id] as int])
	return "BOT [%s] seed %d lean %s pace %d: %s | ур. города %d | жители %d (пик %d, 12 с дня %d) | сч %d | доверие %d · поддержка %d | деньги %d | голодных вечеров %d, сухих %d, хмурых %d | построил %s; улучшений %d, разобрано руин %d" % [
		ContentDB.active_chapter, _bot_seed, _lean if _lean != "" else "—", FRAMES_PER_DAY / _step_every, _ending if _ending != "" else result, GameStateStore.progression().city_level as int,
		pop.get("total", 0) as int, pop.get("peak", 0) as int, _day_twelve, int(pop.get("happiness", 0.0) as float),
		int(mandate.get("patron_trust", 0) as float), int(mandate.get("support", 0) as float), int(GameStateStore.get_resource("res_money")),
		_hungry_evenings, _dry_evenings, _low_mood_evenings, ", ".join(built), _upgrades, _salvaged]
