extends Node
## Central signal hub. Every game-wide event goes through here.
## Systems emit signals; UI and other systems connect to listen.

# --- Economy ---
signal resources_changed(resources: Dictionary)
signal resource_depleted(resource_id: String)
signal production_tick_done()

# --- Buildings ---
signal building_placed(coord: Vector2i, type_id: String)
signal building_removed(coord: Vector2i, type_id: String)
signal building_upgraded(coord: Vector2i, new_level: int)
signal building_repaired(coord: Vector2i)
signal building_damaged(coord: Vector2i, severity: float)
signal building_issue_added(coord: Vector2i)

# --- Infrastructure ---
signal road_network_changed()
signal pipe_network_changed()
signal power_network_changed()
signal power_updated(generation: float, demand: float, tier_powered: Dictionary)
signal coverage_recalculated()

# --- Population & Happiness ---
signal population_changed(total: int)
signal happiness_changed(value: float)

# --- Progression ---
signal city_level_changed(new_level: int)
signal prestige_triggered(stars: int)
signal win_condition_met()

# --- Events (disasters, traders, etc.) ---
signal game_event_spawned(event_data: Dictionary)
signal game_event_resolved(event_id: String, accepted: bool)

# --- Pressure Director ---
signal pressure_updated(index: float, phase: String)

# --- Climate / Seasons ---
signal season_changed(season_id: String, day_in_season: int, length_days: int)
signal season_day_advanced(season_id: String, day_in_season: int, length_days: int)

# --- Diary ---
signal diary_fragment_found(fragment_id: String)

# --- Mandate / Audit ---
signal audit_completed(passed: bool, score: int)

# --- Endings ---
signal ending_triggered(ending_id: String, kind: String)

# --- Save / Load ---
signal game_saved(slot: int)
signal game_loaded(slot: int)
signal new_game_started()

# --- UI hints ---
signal toast_requested(text: String, duration: float)
signal build_mode_changed(type_id: String)
signal selection_changed(coord: Vector2i)
signal ranges_changed(enabled: bool)
signal logistics_lens_changed(enabled: bool)

# --- Tick ---
signal tick_started(tick_number: int)
signal tick_finished(tick_number: int)

# --- Phase System (День / Вечер / Утро) ---
signal phase_changed(new_phase: String)
signal day_timer_updated(seconds_left: float)
signal evening_started(pending_events: Array)
signal morning_consequences(results: Array)

# --- Стол Администратора ---
signal critical_event_started(event_data: Dictionary)
signal desk_opened(events: Array)
signal desk_option_selected(event_id: String, option_index: int, effects: Dictionary, cost: Dictionary)
signal desk_closed()
