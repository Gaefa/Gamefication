class_name SaveValidator
## Validates save data against SaveSchemaV1.

static func validate(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []

	if not data.has("meta"):
		errors.append("Missing 'meta' section")
		return errors

	var meta: Dictionary = data.get("meta", {})
	var version: int = meta.get("schema_version", 0) as int
	if version != SaveSchemaV1.VERSION:
		errors.append("Schema version mismatch: expected %d, got %d" % [SaveSchemaV1.VERSION, version])

	for section: String in SaveSchemaV1.REQUIRED_SECTIONS:
		if not data.has(section):
			errors.append("Missing section: %s" % section)

	# Every section is a dictionary; a save that says otherwise is refused before it touches the game.
	for section: String in SaveSchemaV1.REQUIRED_SECTIONS:
		if data.has(section) and not data[section] is Dictionary:
			errors.append("section is not a dictionary: %s" % section)
	if not errors.is_empty():
		return errors

	var world: Dictionary = data.world
	for key: String in SaveSchemaV1.WORLD_KEYS:
		if not world.has(key):
			errors.append("world missing key: %s" % key)
	for key: String in ["terrain", "buildings"]:
		if world.has(key) and not world[key] is Dictionary:
			errors.append("world.%s is not a dictionary" % key)

	var economy: Dictionary = data.economy
	for key: String in SaveSchemaV1.ECONOMY_KEYS:
		if not economy.has(key):
			errors.append("economy missing key: %s" % key)
	for key: String in ["resources", "caps", "production"]:
		if economy.has(key) and not economy[key] is Dictionary:
			errors.append("economy.%s is not a dictionary" % key)
	if economy.has("buffs") and not economy["buffs"] is Array:
		errors.append("economy.buffs is not an array")

	var events: Dictionary = data.events
	if events.has("active") and not events["active"] is Array:
		errors.append("events.active is not an array")
	if events.has("cooldowns") and not events["cooldowns"] is Dictionary:
		errors.append("events.cooldowns is not a dictionary")

	return errors
