extends Node
## 3-slot save/load system with autosave support.

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
	return true


func load_game(slot: int) -> bool:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		push_warning("SaveService: no save at slot %d" % slot)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("SaveService: parse error in slot %d" % slot)
		return false
	var data: Variant = json.data
	if not data is Dictionary:
		return false
	GameStateStore.load_from_dict(data as Dictionary)
	EventBus.game_loaded.emit(slot)
	return true


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot))


func delete_save(slot: int) -> void:
	var path := _slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _slot_path(slot: int) -> String:
	return SAVE_DIR + "save_%d.json" % slot
