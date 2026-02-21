class_name EventSystem
## Spawns random game events based on pressure phase, city level, and cooldowns.
## Active events have timers; unresolved events auto-decline when timer expires.

var _rng: SeededRNG

const EVENT_CHECK_INTERVAL := 30  # check every N ticks
const BASE_EVENT_CHANCE := 0.15


func _init(rng: SeededRNG) -> void:
	_rng = rng


func process_tick() -> void:
	var tick: int = GameStateStore.get_tick()
	var ev_state: Dictionary = GameStateStore.events()

	# Tick down active event timers
	var still_active: Array = []
	for ev: Dictionary in ev_state.active:
		var timer: float = (ev.get("timer", 0.0) as float) - 1.0
		if timer <= 0.0:
			_auto_decline(ev)
		else:
			ev["timer"] = timer
			still_active.append(ev)
	ev_state.active = still_active

	# Tick down cooldowns
	var cd: Dictionary = ev_state.cooldowns
	var expired_cds: Array = []
	for ev_id: String in cd:
		cd[ev_id] = (cd[ev_id] as int) - 1
		if (cd[ev_id] as int) <= 0:
			expired_cds.append(ev_id)
	for ev_id: String in expired_cds:
		cd.erase(ev_id)

	# Maybe spawn a new event
	if tick % EVENT_CHECK_INTERVAL == 0 and ev_state.active.size() < 2:
		_try_spawn_event()


func _try_spawn_event() -> void:
	var city_level: int = GameStateStore.progression().city_level as int
	var phase: String = GameStateStore.pressure().phase as String
	var phase_num: int = _phase_to_int(phase)

	# Collect eligible events
	var eligible: Array = []
	var cd: Dictionary = GameStateStore.events().cooldowns
	for ev_id: String in ContentDB.get_event_ids():
		if cd.has(ev_id):
			continue
		var def: Dictionary = ContentDB.get_event_def(ev_id)
		if (def.get("min_level", 1) as int) > city_level:
			continue
		if (def.get("pressure_phase_min", 0) as int) > phase_num:
			continue
		eligible.append(ev_id)

	if eligible.is_empty():
		return

	# Chance scales with pressure
	var chance: float = BASE_EVENT_CHANCE + GameStateStore.pressure().index as float * 0.003
	if not _rng.chance(chance):
		return

	# Pick random event
	var idx: int = _rng.range_int(0, eligible.size())
	var ev_id: String = eligible[idx] as String
	var def: Dictionary = ContentDB.get_event_def(ev_id)

	var active_ev: Dictionary = {
		"id": ev_id,
		"timer": 60.0,  # 60 seconds to respond
		"spawned_tick": GameStateStore.get_tick(),
	}
	GameStateStore.events().active.append(active_ev)
	GameStateStore.events().cooldowns[ev_id] = 300  # 5 min cooldown

	EventBus.game_event_spawned.emit(def)


func _auto_decline(ev: Dictionary) -> void:
	var ev_id: String = ev.get("id", "") as String
	var def: Dictionary = ContentDB.get_event_def(ev_id)
	_apply_effects(def.get("decline_effects", {}))
	EventBus.game_event_resolved.emit(ev_id, false)


func resolve_event(ev_id: String, accept: bool) -> void:
	var ev_state: Dictionary = GameStateStore.events()
	var def: Dictionary = ContentDB.get_event_def(ev_id)

	if accept:
		var cost_raw: Variant = def.get("accept_cost", null)
		var cost: Dictionary = cost_raw as Dictionary if cost_raw is Dictionary else {}
		if not cost.is_empty():
			if not GameStateStore.can_afford(cost):
				return
			GameStateStore.spend(cost)
		var eff_raw: Variant = def.get("accept_effects", null)
		var accept_effects: Dictionary = eff_raw as Dictionary if eff_raw is Dictionary else {}
		_apply_effects(accept_effects)
	else:
		_apply_effects(def.get("decline_effects", {}))

	# Remove from active
	var keep: Array = []
	for ev: Dictionary in ev_state.active:
		if (ev.get("id", "") as String) != ev_id:
			keep.append(ev)
	ev_state.active = keep

	EventBus.game_event_resolved.emit(ev_id, accept)


func _apply_effects(effects: Dictionary) -> void:
	if effects.is_empty():
		return

	for key: String in effects:
		if key == "add_buff":
			var buff_raw: Variant = effects[key]
			if buff_raw is Dictionary:
				GameStateStore.add_buff((buff_raw as Dictionary).duplicate())
		elif key == "add_resources":
			var res_dict: Variant = effects[key]
			if res_dict is Dictionary:
				for res_id: String in (res_dict as Dictionary):
					GameStateStore.add_resource(res_id, (res_dict as Dictionary)[res_id] as float)
		elif key == "remove_resources":
			var res_dict: Variant = effects[key]
			if res_dict is Dictionary:
				for res_id: String in (res_dict as Dictionary):
					GameStateStore.add_resource(res_id, -((res_dict as Dictionary)[res_id] as float))
		elif key == "force_issues":
			_force_issues(effects[key] as int)
		elif key == "damage_buildings":
			_damage_random_buildings(effects[key] as int)
		elif key == "message":
			EventBus.toast_requested.emit(effects[key] as String, 5.0)


func _force_issues(count: int) -> void:
	var coords: Array = GameStateStore.get_all_building_coords()
	for i: int in mini(count, coords.size()):
		var idx: int = _rng.range_int(0, coords.size())
		var coord: Vector2i = coords[idx] as Vector2i
		var bld: Dictionary = GameStateStore.get_building(coord)
		bld["has_issue"] = true
		GameStateStore.set_building(coord, bld)


func _damage_random_buildings(count: int) -> void:
	var coords: Array = GameStateStore.get_all_building_coords()
	for i: int in mini(count, coords.size()):
		var idx: int = _rng.range_int(0, coords.size())
		var coord: Vector2i = coords[idx] as Vector2i
		var bld: Dictionary = GameStateStore.get_building(coord)
		if (bld.get("type", "") as String) == "road":
			continue
		bld["damaged"] = true
		GameStateStore.set_building(coord, bld)
		EventBus.building_damaged.emit(coord, 1.0)


func _phase_to_int(phase: String) -> int:
	match phase:
		"calm": return 0
		"tension": return 1
		"crisis": return 2
		"emergency": return 3
	return 0
