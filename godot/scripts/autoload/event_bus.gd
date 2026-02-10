## event_bus.gd -- Global signal hub (autoload singleton).
## All game-wide signals are declared here so any node can emit or
## connect without hard dependencies.
class_name EventBusClass
extends Node

# ---- Building lifecycle ----
signal building_placed(coord: Vector2i, type_id: String)
signal building_removed(coord: Vector2i)
signal building_upgraded(coord: Vector2i, new_level: int)

# ---- Resources ----
signal resource_changed(resource_id: String)
signal resources_changed()

# ---- Simulation tick ----
signal tick_completed(tick_num: int)

# ---- Random / scripted events ----
signal event_fired(event_id: String)
signal event_resolved(event_id: String, accepted: bool)

# ---- State persistence ----
signal state_dirty(section: String)

# ---- Pressure system ----
signal pressure_phase_changed(phase: int)

# ---- Citizen requests ----
signal citizen_request_new(request: Dictionary)
signal citizen_request_resolved(request_id: String)

# ---- Progression ----
signal city_level_changed(new_level: int)
signal prestige_completed(stars_gained: int)

# ---- Session ----
signal game_started()
signal game_loaded(slot: int)
signal game_saved(slot: int)

# ---- Tutorial ----
signal tutorial_step_changed(step_index: int)

# ---- UI / messaging ----
signal message_posted(text: String, duration: float)

# ---- Infrastructure graph invalidation ----
signal coverage_invalidated()
signal network_invalidated()
