extends Node
## 3-slot save/load system with autosave support.
## Integrates SaveMigrator for old saves and SaveValidator for data integrity.

## Dev tools (res://tools/...) play real runs that autosave and reach finales; they get a
## folder of their own so they never overwrite or delete the player's saves.
var SAVE_DIR := "user://saves/"
const AUTOSAVE_INTERVAL := 120.0  # seconds

var _autosave_timer: float = 0.0


func _ready() -> void:
	for arg: String in OS.get_cmdline_args():
		if arg.begins_with("res://tools/"):
			SAVE_DIR = "user://saves_tools/"
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	EventBus.run_reset.connect(func() -> void: _autosave_timer = 0.0)
	# A finished run is not something to continue: the autosave would reopen it a moment
	# before the end, and the same ending would fire again.
	EventBus.ending_triggered.connect(func(_id: String, _kind: String) -> void: delete_save(0))


func _process(delta: float) -> void:
	# Only a run in progress autosaves: never the throwaway map behind the start menu
	# (it would overwrite the save "Continue" loads) and never a finished game.
	if not SimulationRunner.run_active:
		return
	_autosave_timer += delta
	# Only mid-day: a save taken at the Desk (or under an urgent card) would load into a
	# fresh day with the same day number — a free day of production.
	if SimulationRunner.current_phase != SimulationRunner.Phase.DAY or SimulationRunner.card_open:
		return
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		save_game(0, true)  # slot 0 = autosave (silent)


func save_game(slot: int, silent: bool = false) -> bool:
	var path := _slot_path(slot)
	# The time left in the current day rides the save, so a load doesn't refill the day.
	GameStateStore.climate()["day_timer"] = SimulationRunner.day_timer
	var data: Dictionary = GameStateStore.to_save_dict()
	data["save_time"] = Time.get_datetime_string_from_system()
	(data["meta"] as Dictionary)["game_version"] = ProjectSettings.get_setting("application/config/version", "")
	# Keep key order (systems iterate buildings in insertion order) and full float
	# precision, so a load resumes the simulation tick-for-tick.
	var json_str := JSON.stringify(data, "\t", false, true)
	# Write beside the slot and swap in, so a crash mid-write leaves the old save intact.
	var tmp_path := path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveService: cannot write to %s" % tmp_path)
		return false
	file.store_string(json_str)
	file.close()
	if DirAccess.rename_absolute(tmp_path, path) != OK:
		push_error("SaveService: cannot replace %s" % path)
		return false
	EventBus.game_saved.emit(slot)
	if not silent:
		EventBus.toast_requested.emit(Localization.t("ui.save.saved", "Game saved (slot %d)") % slot, 2.0)
	return true


func load_game(slot: int) -> bool:
	var path := _slot_path(slot)
	_recover_tmp(path)
	if not FileAccess.file_exists(path):
		push_warning("SaveService: no save at slot %d" % slot)
		EventBus.toast_requested.emit(Localization.t("ui.save.no_save", "No save in slot %d") % slot, 3.0)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SaveService: cannot open slot %d" % slot)
		return false
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("SaveService: parse error in slot %d: %s" % [slot, json.get_error_message()])
		EventBus.toast_requested.emit(Localization.t("ui.save.corrupted", "Save file corrupted (slot %d)") % slot, 4.0)
		return false

	var data: Variant = json.data
	if not data is Dictionary:
		push_error("SaveService: expected Dictionary in slot %d" % slot)
		EventBus.toast_requested.emit(Localization.t("ui.save.invalid", "Save file invalid (slot %d)") % slot, 4.0)
		return false

	# Migrate old format saves to current schema
	var migrated: Dictionary = SaveMigrator.migrate(data as Dictionary)

	# Validate after migration
	var errors: Array[String] = SaveValidator.validate(migrated)
	if not errors.is_empty():
		push_warning("SaveService: validation errors in slot %d:" % slot)
		for err: String in errors:
			push_warning("  - %s" % err)
		EventBus.toast_requested.emit(Localization.t("ui.save.invalid", "Save file invalid (slot %d)") % slot, 4.0)
		return false

	GameStateStore.load_from_dict(migrated)
	EventBus.game_loaded.emit(slot)
	EventBus.toast_requested.emit(Localization.t("ui.save.loaded", "Game loaded (slot %d)") % slot, 2.0)
	return true


func has_save(slot: int) -> bool:
	var path := _slot_path(slot)
	_recover_tmp(path)
	return FileAccess.file_exists(path)


func delete_save(slot: int) -> void:
	var path := _slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	if FileAccess.file_exists(path + ".tmp"):
		DirAccess.remove_absolute(path + ".tmp")


## On Windows the swap in save_game() is remove-then-rename: a crash between the two
## leaves only the finished .tmp. A complete .tmp with no slot beside it becomes the slot.
func _recover_tmp(path: String) -> void:
	var tmp_path := path + ".tmp"
	if FileAccess.file_exists(path) or not FileAccess.file_exists(tmp_path):
		return
	var file := FileAccess.open(tmp_path, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	if JSON.new().parse(text) == OK:
		DirAccess.rename_absolute(tmp_path, path)
	else:
		DirAccess.remove_absolute(tmp_path)


func _slot_path(slot: int) -> String:
	return SAVE_DIR + "save_%d.json" % slot
