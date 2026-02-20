## save_service.gd -- Manages save/load with 3 slots.
## Autosaves periodically while playing.  Calculates offline ticks on load.
class_name SaveServiceClass
extends Node

const MAX_SLOTS: int = 3
const AUTOSAVE_INTERVAL: float = 5.0   # seconds between autosaves
const MAX_OFFLINE_SECONDS: int = 14400  # 4 hours max offline progression
const SAVE_DIR: String = "user://"
const SAVE_PREFIX: String = "slot_"
const SAVE_EXT: String = ".json"

var _autosave_timer: float = 0.0

# ------------------------------------------------------------------
# Lifecycle
# ------------------------------------------------------------------

func _process(delta: float) -> void:
	if not GameStateStore.is_playing:
		return
	if GameStateStore.current_slot < 0:
		return

	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		save_game(GameStateStore.current_slot)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if GameStateStore.is_playing and GameStateStore.current_slot >= 0:
			save_game(GameStateStore.current_slot)
			print("SaveService: saved on quit (slot %d)." % GameStateStore.current_slot)


# ------------------------------------------------------------------
# Save
# ------------------------------------------------------------------

func save_game(slot: int) -> bool:
	if slot < 0 or slot >= MAX_SLOTS:
		push_warning("SaveService: invalid slot %d." % slot)
		return false

	# Stamp save time
	var meta: Dictionary = GameStateStore.get_meta()
	meta["last_saved_at"] = Time.get_unix_time_from_system()

	# Serialize
	var json_text: String = JSON.stringify(GameStateStore.state, "\t")
	var path: String = _slot_path(slot)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("SaveService: could not open %s for writing (error %d)." % [path, FileAccess.get_open_error()])
		return false

	file.store_string(json_text)
	file.close()

	GameStateStore.current_slot = slot
	EventBus.game_saved.emit(slot)
	return true


# ------------------------------------------------------------------
# Load
# ------------------------------------------------------------------

func load_game(slot: int) -> bool:
	if slot < 0 or slot >= MAX_SLOTS:
		push_warning("SaveService: invalid slot %d." % slot)
		return false

	var path: String = _slot_path(slot)
	if not FileAccess.file_exists(path):
		push_warning("SaveService: slot %d file not found." % slot)
		return false

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("SaveService: could not open %s for reading (error %d)." % [path, FileAccess.get_open_error()])
		return false

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		push_warning("SaveService: failed to parse save file for slot %d." % slot)
		return false

	var loaded_state: Dictionary = parsed

	# Basic validation -- check required top-level keys
	var required_keys: Array[String] = ["world", "economy", "population", "progression", "pressure", "events", "meta"]
	for key: String in required_keys:
		if not loaded_state.has(key):
			push_warning("SaveService: save file missing section '%s'." % key)
			return false

	# Apply to GameStateStore
	GameStateStore.state = loaded_state
	GameStateStore.current_slot = slot
	GameStateStore.is_playing = true

	# Calculate offline ticks
	var meta: Dictionary = GameStateStore.get_meta()
	var last_saved: float = float(meta.get("last_saved_at", 0.0))
	if last_saved > 0.0:
		var now: float = Time.get_unix_time_from_system()
		var elapsed: float = maxf(now - last_saved, 0.0)
		var offline_seconds: int = mini(int(elapsed), MAX_OFFLINE_SECONDS)
		var offline_ticks: int = int(offline_seconds / SimulationRunner.TICK_INTERVAL)
		if offline_ticks > 0:
			print("SaveService: %d seconds offline -> %d ticks." % [offline_seconds, offline_ticks])
			SimulationRunner.run_offline_ticks(offline_ticks)

	# Sync SimulationRunner tick count
	SimulationRunner.tick_count = int(meta.get("tick_count", 0))

	_autosave_timer = 0.0
	EventBus.game_loaded.emit(slot)
	return true


# ------------------------------------------------------------------
# Slot info
# ------------------------------------------------------------------

func get_slot_info(slot: int) -> Dictionary:
	if slot < 0 or slot >= MAX_SLOTS:
		return {}

	var path: String = _slot_path(slot)
	if not FileAccess.file_exists(path):
		return { "exists": false }

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return { "exists": false }

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		return { "exists": false }

	var data: Dictionary = parsed
	var meta: Dictionary = data.get("meta", {})
	var progression: Dictionary = data.get("progression", {})
	var population: Dictionary = data.get("population", {})

	return {
		"exists": true,
		"saved_at": float(meta.get("last_saved_at", 0.0)),
		"play_time": float(meta.get("play_time", 0.0)),
		"city_level": int(progression.get("city_level", 1)),
		"population": int(population.get("total", 0)),
		"prestige_stars": int(progression.get("prestige_stars", 0)),
	}


func get_all_slots_info() -> Array:
	var result: Array = []
	for i: int in range(MAX_SLOTS):
		result.append(get_slot_info(i))
	return result


# ------------------------------------------------------------------
# Delete
# ------------------------------------------------------------------

func delete_slot(slot: int) -> void:
	if slot < 0 or slot >= MAX_SLOTS:
		push_warning("SaveService: invalid slot %d for deletion." % slot)
		return

	var path: String = _slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		print("SaveService: deleted slot %d." % slot)


# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------

func _slot_path(slot: int) -> String:
	return SAVE_DIR + SAVE_PREFIX + str(slot) + SAVE_EXT
