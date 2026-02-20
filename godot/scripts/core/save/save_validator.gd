## save_validator.gd -- Validates save data against the current schema.
## Reports missing sections, invalid types, and data integrity issues.
## Used before loading a save to ensure it won't crash the game.
class_name SaveValidator


## Validation result.
class ValidationResult:
	var is_valid: bool = true
	var errors: Array = []
	var warnings: Array = []

	func add_error(msg: String) -> void:
		errors.append(msg)
		is_valid = false

	func add_warning(msg: String) -> void:
		warnings.append(msg)

	func get_summary() -> String:
		var lines: Array = []
		if is_valid:
			lines.append("Save is valid.")
		else:
			lines.append("Save is INVALID.")
		for e: String in errors:
			lines.append("  ERROR: %s" % e)
		for w: String in warnings:
			lines.append("  WARNING: %s" % w)
		return "\n".join(lines)


## Validate the given state dictionary against SaveSchemaV1.
## Returns a ValidationResult with errors and warnings.
static func validate(state: Dictionary) -> ValidationResult:
	var result := ValidationResult.new()

	if state.is_empty():
		result.add_error("State dictionary is empty.")
		return result

	# Check schema version
	var version: int = int(state.get("schema_version", 0))
	if version < SaveSchemaV1.VERSION:
		result.add_warning("Schema version %d is older than current v%d. Migration needed." % [version, SaveSchemaV1.VERSION])

	# Check required sections
	for section: String in SaveSchemaV1.required_sections():
		if not state.has(section):
			result.add_error("Missing required section: '%s'" % section)
			continue
		if not (state[section] is Dictionary):
			result.add_error("Section '%s' must be a Dictionary, got %s" % [section, type_string(typeof(state[section]))])
			continue

	# Check required keys within sections
	var required_keys: Dictionary = SaveSchemaV1.required_keys()
	for section: String in required_keys:
		if not state.has(section) or not (state[section] is Dictionary):
			continue
		var section_data: Dictionary = state[section]
		var keys: Array = required_keys[section]
		for key: String in keys:
			if not section_data.has(key):
				result.add_error("Missing required key '%s' in section '%s'" % [key, section])

	# Validate world section
	if state.has("world") and state["world"] is Dictionary:
		_validate_world(state["world"], result)

	# Validate economy section
	if state.has("economy") and state["economy"] is Dictionary:
		_validate_economy(state["economy"], result)

	# Validate progression section
	if state.has("progression") and state["progression"] is Dictionary:
		_validate_progression(state["progression"], result)

	# Validate pressure section
	if state.has("pressure") and state["pressure"] is Dictionary:
		_validate_pressure(state["pressure"], result)

	return result


## Validate world section specifics.
static func _validate_world(world: Dictionary, result: ValidationResult) -> void:
	var grid_size: int = int(world.get("grid_size", 0))
	if grid_size <= 0 or grid_size > 256:
		result.add_error("world.grid_size must be 1-256, got %d" % grid_size)

	var buildings: Dictionary = world.get("buildings", {})
	var building_schema: Dictionary = SaveSchemaV1.building_schema()

	for key: String in buildings:
		var bld = buildings[key]
		if not (bld is Dictionary):
			result.add_error("Building at '%s' is not a Dictionary." % key)
			continue

		# Check required building keys
		if not bld.has("type"):
			result.add_error("Building at '%s' missing 'type'." % key)
		elif not (bld["type"] is String):
			result.add_error("Building at '%s' type must be String." % key)

		if not bld.has("level"):
			result.add_warning("Building at '%s' missing 'level', defaulting to 1." % key)

		# Validate level range
		var level: int = int(bld.get("level", 1))
		if level < 1 or level > 5:
			result.add_warning("Building at '%s' has unusual level %d." % [key, level])

		# Validate building type exists in ContentDB
		var btype: String = str(bld.get("type", ""))
		if btype != "" and ContentDB and ContentDB.has_method("get_building"):
			var bdef: Dictionary = ContentDB.get_building(btype)
			if bdef.is_empty():
				result.add_warning("Building at '%s' has unknown type '%s'." % [key, btype])


## Validate economy section specifics.
static func _validate_economy(economy: Dictionary, result: ValidationResult) -> void:
	var resources = economy.get("resources", {})
	if not (resources is Dictionary):
		result.add_error("economy.resources must be a Dictionary.")
		return

	# Check for negative resource values
	for rid: String in resources:
		var val: float = float(resources[rid])
		if val < 0.0:
			result.add_warning("economy.resources.%s is negative: %f" % [rid, val])

	# Check caps
	var caps = economy.get("caps", {})
	if caps is Dictionary:
		for rid: String in caps:
			var cap: float = float(caps[rid])
			if cap <= 0.0:
				result.add_warning("economy.caps.%s is non-positive: %f" % [rid, cap])


## Validate progression section specifics.
static func _validate_progression(progression: Dictionary, result: ValidationResult) -> void:
	var city_level: int = int(progression.get("city_level", 1))
	if city_level < 1 or city_level > 10:
		result.add_warning("progression.city_level %d seems unusual." % city_level)

	var prestige_stars: int = int(progression.get("prestige_stars", 0))
	if prestige_stars < 0:
		result.add_error("progression.prestige_stars cannot be negative.")


## Validate pressure section specifics.
static func _validate_pressure(pressure: Dictionary, result: ValidationResult) -> void:
	var index: float = float(pressure.get("index", 0.0))
	if index < 0.0 or index > 100.0:
		result.add_warning("pressure.index %f is outside [0, 100] range." % index)

	var phase: int = int(pressure.get("phase", 0))
	if phase < 0 or phase > 3:
		result.add_warning("pressure.phase %d is outside [0, 3] range." % phase)
