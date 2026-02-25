extends Node
## 3-slot save/load system with autosave support.
## Integrates SaveMigrator for old saves and SaveValidator for data integrity.

const SAVE_DIR := "user://saves/"
const AUTOSAVE_INTERVAL := 120.0  # seconds

var _autosave_timer: float = 0.0


func _ready() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func _process(delta: float) -> void:
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		save_game(0)  # slot 0 = autosave


func save_game(slot: int) -> bool:
	var path := _slot_path(slot)
	var data: Dictionary = GameStateStore.to_save_dict()
	data["save_time"] = Time.get_datetime_string_from_system()
	var json_str := JSON.stringify(data, "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveService: cannot write to %s" % path)
		return false
	file.store_string(json_str)
	file.close()
	EventBus.game_saved.emit(slot)
	EventBus.toast_requested.emit("Game saved (slot %d)" % slot, 2.0)
	return true


func load_game(slot: int) -> bool:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		push_warning("SaveService: no save at slot %d" % slot)
		EventBus.toast_requested.emit("No save in slot %d" % slot, 3.0)
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
		EventBus.toast_requested.emit("Save file corrupted (slot %d)" % slot, 4.0)
		return false

	var data: Variant = json.data
	if not data is Dictionary:
		push_error("SaveService: expected Dictionary in slot %d" % slot)
		EventBus.toast_requested.emit("Save file invalid (slot %d)" % slot, 4.0)
		return false

	# Migrate old format saves to current schema
	var migrated: Dictionary = SaveMigrator.migrate(data as Dictionary)

	# Validate after migration
	var errors: Array[String] = SaveValidator.validate(migrated)
	if not errors.is_empty():
		push_warning("SaveService: validation errors in slot %d:" % slot)
		for err: String in errors:
			push_warning("  - %s" % err)
		# Try to load anyway — validator warnings are non-fatal
		# But toast the user about potential issues
		EventBus.toast_requested.emit("Save loaded with %d warning(s)" % errors.size(), 4.0)

	GameStateStore.load_from_dict(migrated)
	EventBus.game_loaded.emit(slot)
	EventBus.toast_requested.emit("Game loaded (slot %d)" % slot, 2.0)
	return true


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot))


func delete_save(slot: int) -> void:
	var path := _slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _slot_path(slot: int) -> String:
	return SAVE_DIR + "save_%d.json" % slot
