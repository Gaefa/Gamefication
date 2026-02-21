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

	if data.has("world"):
		var world: Dictionary = data.world
		for key: String in SaveSchemaV1.WORLD_KEYS:
			if not world.has(key):
				errors.append("world missing key: %s" % key)

	if data.has("economy"):
		var economy: Dictionary = data.economy
		for key: String in SaveSchemaV1.ECONOMY_KEYS:
			if not economy.has(key):
				errors.append("economy missing key: %s" % key)

	return errors
