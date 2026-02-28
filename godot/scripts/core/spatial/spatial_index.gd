class_name SpatialIndex
## O(1) lookup of building coordinates by type.
## Maintained incrementally as buildings are placed/removed.

var _by_type: Dictionary = {}      # type_id → Dictionary[Vector2i, bool]
var _by_category: Dictionary = {}  # category → Dictionary[Vector2i, bool]


func add(coord: Vector2i, type_id: String) -> void:
	if not _by_type.has(type_id):
		_by_type[type_id] = {}
	_by_type[type_id][coord] = true

	var cat: String = _category_of(type_id)
	if cat != "":
		if not _by_category.has(cat):
			_by_category[cat] = {}
		_by_category[cat][coord] = true


func remove(coord: Vector2i, type_id: String) -> void:
	if _by_type.has(type_id):
		(_by_type[type_id] as Dictionary).erase(coord)
	var cat: String = _category_of(type_id)
	if cat != "" and _by_category.has(cat):
		(_by_category[cat] as Dictionary).erase(coord)


func get_coords_of_type(type_id: String) -> Array[Vector2i]:
	if not _by_type.has(type_id):
		return []
	var result: Array[Vector2i] = []
	for c: Vector2i in (_by_type[type_id] as Dictionary).keys():
		result.append(c)
	return result


func get_coords_of_category(category: String) -> Array[Vector2i]:
	if not _by_category.has(category):
		return []
	var result: Array[Vector2i] = []
	for c: Vector2i in (_by_category[category] as Dictionary).keys():
		result.append(c)
	return result


func count_type(type_id: String) -> int:
	if not _by_type.has(type_id):
		return 0
	return (_by_type[type_id] as Dictionary).size()


func clear() -> void:
	_by_type.clear()
	_by_category.clear()


func rebuild_from_state() -> void:
	clear()
	for coord: Vector2i in GameStateStore.get_all_building_coords():
		var bld: Dictionary = GameStateStore.get_building(coord)
		add(coord, bld.get("type", "") as String)


func _category_of(type_id: String) -> String:
	var def: Dictionary = ContentDB.get_building_def(type_id)
	return def.get("category", "") as String
