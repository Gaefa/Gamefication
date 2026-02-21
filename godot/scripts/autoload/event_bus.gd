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

# --- Infrastructure ---
signal road_network_changed()
signal pipe_network_changed()
signal power_network_changed()
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

# --- Save / Load ---
signal game_saved(slot: int)
signal game_loaded(slot: int)
signal new_game_started()

# --- UI hints ---
signal toast_requested(text: String, duration: float)
signal build_mode_changed(type_id: String)
signal selection_changed(coord: Vector2i)

# --- Tick ---
signal tick_started(tick_number: int)
signal tick_finished(tick_number: int)
