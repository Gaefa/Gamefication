extends "res://tools/loop_smoke.gd"
## Stress test: plays the real loop with random answers at the Desk and random player
## actions during the day — building (on valid and invalid cells), upgrading, repairing,
## demolishing (protected buildings too), research, policies, a save and load in the middle
## of a day — and after every evening checks that the game state is still sane.
## It looks for crashes, script errors and impossible numbers, not for balance.
##
## Run: Godot --headless --fixed-fps 60 --path <proj> res://tools/fuzz_smoke.tscn -- seed=1
## Dev tool, not shipped.

const TEST_SLOT := 9
const ACTION_EVERY := 3      # sim frames between two random actions: about twenty a day

var _rng := RandomNumberGenerator.new()
var _frame: int = 0
var _actions: int = 0
var _accepted: int = 0
var _violations: int = 0
var _saves: int = 0
var _verbose: bool = false


func _ready() -> void:
	_rng.seed = 1
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("seed="):
			_rng.seed = arg.trim_prefix("seed=").to_int()
		elif arg == "verbose":
			_verbose = true
	EventBus.evening_started.connect(func(_events: Array) -> void: _check_state("вечер"))
	super._ready()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _desk == null or _ending != "" or _desk.visible or SimulationRunner.paused or not SimulationRunner.run_active:
		return
	_frame += 1
	if _frame % ACTION_EVERY == 0:
		_random_action()


# --- the Desk: any answer the district can pay for ---

func _auto_resolve() -> void:
	if (_desk.get("_finish_btn") as Button).visible or (_desk.get("_next_btn") as Button).visible:
		super._auto_resolve()
		return
	var events: Array = _desk.get("_events") as Array
	var idx: int = _desk.get("_current_index") as int
	if idx >= events.size():
		return
	var evt: Dictionary = events[idx] as Dictionary
	var affordable: Array = []
	for option: Variant in evt.get("options", []) as Array:
		var cost: Dictionary = (option as Dictionary).get("cost", {})
		if cost.is_empty() or GameStateStore.can_afford(cost):
			affordable.append(option)
	if affordable.is_empty():
		_violation("у карты %s нет ни одного доступного ответа" % (evt.get("runtime_id", "?") as String))
		super._auto_resolve()
		return
	var opt: Dictionary = affordable[_rng.randi() % affordable.size()] as Dictionary
	_cards += 1
	_desk.call("_select_option", evt.get("runtime_id", "") as String, (evt.get("options", []) as Array).find(opt), opt.get("effects", {}), opt.get("cost", {}))


# --- the day: whatever a player could press ---

func _random_action() -> void:
	var orch: GameOrchestrator = _main.call("get_orchestrator") as GameOrchestrator
	var coords: Array = GameStateStore.get_all_building_coords()
	if orch == null or coords.is_empty():
		return
	var any: Vector2i = coords[_rng.randi() % coords.size()] as Vector2i
	var command: CommandBase = null
	# Mostly building and upgrading, so runs live long enough to meet the Dust, the audit and
	# the late letters; demolition is rare and spares water and housing (a district that
	# tears down its only pump is dead in two days, which tests nothing further).
	var roll: int = _rng.randi() % 100
	var action: int = 0 if roll < 50 else (4 if roll < 75 else (6 if roll < 85 else (8 if roll < 92 else (9 if roll < 97 else 7))))
	match action:
		0, 1, 2, 3:
			# Next to something built; one time in five somewhere far or outside the map.
			var cell: Vector2i = any + Vector2i(_rng.randi_range(-2, 2), _rng.randi_range(-2, 2))
			if _rng.randi() % 5 == 0:
				cell = Vector2i(_rng.randi_range(-45, 45), _rng.randi_range(-45, 45))
			var ids: Array = ContentDB.get_building_ids()
			command = PlaceBuildingCommand.new(cell, ids[_rng.randi() % ids.size()] as String)
		4, 5:
			command = UpgradeBuildingCommand.new(any)
		6:
			command = RepairBuildingCommand.new(any)
		7:
			var tags: Array = ContentDB.get_building_def(GameStateStore.get_building(any).get("type", "") as String).get("tags", []) as Array
			if tags.has("water_source") or tags.has("housing"):
				return
			command = BulldozeCommand.new(any)
		8:
			var techs: Array = ContentDB.get_technology_ids()
			var policies: Array = ContentDB.get_policy_ids()
			if _rng.randi() % 2 == 0 and not techs.is_empty():
				command = ResearchTechnologyCommand.new(techs[_rng.randi() % techs.size()] as String)
			elif not policies.is_empty():
				command = SetPolicyCommand.new(policies[_rng.randi() % policies.size()] as String)
		9:
			_save_and_load()
			return
	if command == null:
		return
	_actions += 1
	var protected: bool = BulldozeCommand.is_protected(ContentDB.get_building_def(GameStateStore.get_building(any).get("type", "") as String))
	orch.command_bus.execute(command)
	if command.success:
		_accepted += 1
		if _verbose:
			var pop: Dictionary = GameStateStore.population()
			print("  день %d тик %d: %s %s → жителей %d (мест %d, обслужено %d)" % [SimulationRunner.day_count, GameStateStore.get_tick(),
				(command.get_script() as Script).resource_path.get_file().trim_suffix("_command.gd"), command.message,
				pop.get("total", 0) as int, pop.get("capacity", 0) as int, pop.get("served", 0) as int])
	if command is BulldozeCommand and protected and not GameStateStore.has_building(any):
		_violation("снесено защищённое здание на %s" % str(any))
	_check_state("действие %d" % _actions)


## A save in the middle of a day must come back as the very same state.
func _save_and_load() -> void:
	if not SaveService.save_game(TEST_SLOT, true):
		_violation("сохранение не записалось")
		return
	var before: Dictionary = _snapshot()
	if not SaveService.load_game(TEST_SLOT):
		_violation("сохранение не загрузилось")
		return
	_saves += 1
	if _verbose:
		print("  день %d: сохранение и загрузка → жителей %d" % [SimulationRunner.day_count, GameStateStore.population().get("total", 0) as int])
	var after: Dictionary = _snapshot()
	for key: String in before:
		if JSON.stringify(before[key]) != JSON.stringify(after[key]):
			_violation("после загрузки отличается «%s»: было %s, стало %s" % [key, JSON.stringify(before[key]), JSON.stringify(after[key])])
	SimulationRunner.speed_scale = SPEED


func _snapshot() -> Dictionary:
	var resources: Dictionary = {}
	for res_id: String in ContentDB.get_resource_ids():
		resources[res_id] = snappedf(GameStateStore.get_resource(res_id), 0.01)
	return {
		"resources": resources,
		"buildings": GameStateStore.get_all_building_coords().size(),
		# Numbers come back from JSON as floats: compare values, not types.
		"day": float(GameStateStore.climate().get("total_day", 0)),
		"population": float(GameStateStore.population().get("total", 0)),
		"buffs": GameStateStore.get_buffs().size(),
		"trust": snappedf(float(GameStateStore.mandate().get("patron_trust", 0)), 0.001),
		"support": snappedf(float(GameStateStore.mandate().get("support", 0)), 0.001),
		"pending": EventManager.pending_events.size(),
	}


# --- what must always hold ---

func _check_state(where: String) -> void:
	for res_id: String in ContentDB.get_resource_ids():
		var value: float = GameStateStore.get_resource(res_id)
		var cap: float = GameStateStore.get_cap(res_id)
		if is_nan(value) or is_inf(value):
			_violation("%s: %s = %s" % [where, res_id, str(value)])
		elif value < -0.01:
			_violation("%s: %s ушёл в минус (%.2f)" % [where, res_id, value])
		elif cap > 0.0 and value > cap + 0.51:
			_violation("%s: %s выше ёмкости (%.1f из %.1f)" % [where, res_id, value, cap])
	var population: Dictionary = GameStateStore.population()
	if (population.get("total", 0) as int) < 0:
		_violation("%s: отрицательное население" % where)
	_in_range(where, "счастье", population.get("happiness", 50.0) as float)
	_in_range(where, "доверие", GameStateStore.mandate().get("patron_trust", 50) as float)
	_in_range(where, "поддержка", GameStateStore.mandate().get("support", 50) as float)
	var categories: Dictionary = GameStateStore.pressure().get("categories", {}) as Dictionary
	for category: String in categories:
		_in_range(where, "давление " + category, categories[category] as float)
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var bld: Dictionary = GameStateStore.get_building(coord)
		var type_id: String = bld.get("type", "") as String
		if ContentDB.get_building_def(type_id).is_empty():
			_violation("%s: неизвестное здание '%s' на %s" % [where, type_id, str(coord)])
		elif (bld.get("level", 0) as int) < 0 or (bld.get("level", 0) as int) >= maxi(ContentDB.max_building_level(type_id), 1):
			_violation("%s: %s на %s имеет уровень %d" % [where, type_id, str(coord), bld.get("level", 0) as int])
	for buff: Dictionary in GameStateStore.get_buffs():
		if (buff.get("remaining", 0.0) as float) <= 0.0:
			_violation("%s: истёкший эффект не убран" % where)
	if _first_of("bld_main_cistern") == Vector2i(-9999, -9999) or _first_of("bld_admin_post") == Vector2i(-9999, -9999):
		_violation("%s: пропала Цистерна или пост администрации" % where)


func _in_range(where: String, what: String, value: float) -> void:
	if is_nan(value) or value < -0.01 or value > 100.01:
		_violation("%s: %s вне 0–100 (%s)" % [where, what, str(value)])


func _first_of(type_id: String) -> Vector2i:
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		if (GameStateStore.get_building(coord).get("type", "") as String) == type_id:
			return coord
	return Vector2i(-9999, -9999)


func _violation(text: String) -> void:
	_violations += 1
	if _violations <= 25:
		print("НАРУШЕНИЕ: " + text)


func _finish(result: String) -> void:
	SaveService.delete_save(TEST_SLOT)
	print("=== FUZZ: seed %d | действий %d (принято %d), сохранений %d, нарушений %d ===" % [_rng.seed, _actions, _accepted, _saves, _violations])
	super._finish(result)
