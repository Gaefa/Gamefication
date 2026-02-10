## save_migrator.gd -- Migrates old save files to the current schema version.
## Supports migration from v0 (legacy JS format) to v1 (Godot format).
## Each migration function transforms state in-place and bumps schema_version.
class_name SaveMigrator


## Migrate the given state dict to the current schema version.
## Returns true if migration succeeded, false on unrecoverable error.
static func migrate(state: Dictionary) -> bool:
	var current_version: int = int(state.get("schema_version", 0))

	# No schema_version means legacy JS format (v0).
	if not state.has("schema_version"):
		current_version = 0

	# Apply migrations in sequence
	while current_version < SaveSchemaV1.VERSION:
		match current_version:
			0:
				if not _migrate_v0_to_v1(state):
					push_error("SaveMigrator: failed to migrate v0 -> v1")
					return false
				current_version = 1
			_:
				push_error("SaveMigrator: unknown schema version %d" % current_version)
				return false

	return true


## Migrate from v0 (JS legacy format) to v1 (Godot format).
## The JS format has flat keys like "resources", "buildings" as a flat array, etc.
static func _migrate_v0_to_v1(state: Dictionary) -> bool:
	var defaults: Dictionary = SaveSchemaV1.default_state()

	# ---- World section ----
	if not state.has("world"):
		state["world"] = defaults["world"].duplicate(true)

	var world: Dictionary = state["world"]
	# JS used "gridSize" (camelCase) -- convert to snake_case
	if world.has("gridSize"):
		world["grid_size"] = world["gridSize"]
		world.erase("gridSize")
	if not world.has("grid_size"):
		world["grid_size"] = 64

	# JS stored buildings as an object keyed by "x,y" -- same format, keep as-is.
	if not world.has("buildings"):
		world["buildings"] = {}

	# Migrate individual building data from JS format
	var buildings: Dictionary = world.get("buildings", {})
	for key: String in buildings:
		var bld: Dictionary = buildings[key]
		# JS used "type_id" sometimes, normalize to "type"
		if bld.has("type_id") and not bld.has("type"):
			bld["type"] = bld["type_id"]
			bld.erase("type_id")
		# Ensure level exists
		if not bld.has("level"):
			bld["level"] = 1

	# ---- Economy section ----
	if not state.has("economy"):
		state["economy"] = defaults["economy"].duplicate(true)
	var economy: Dictionary = state["economy"]

	# JS may have resources at top level
	if state.has("resources") and not economy.has("resources"):
		economy["resources"] = state["resources"]
		state.erase("resources")
	if state.has("caps") and not economy.has("caps"):
		economy["caps"] = state["caps"]
		state.erase("caps")

	# Ensure required sub-keys
	if not economy.has("resources"):
		economy["resources"] = {}
	if not economy.has("caps"):
		economy["caps"] = {}
	if not economy.has("buffs"):
		economy["buffs"] = []
	if not economy.has("production_rates"):
		economy["production_rates"] = {}
	if not economy.has("consumption_rates"):
		economy["consumption_rates"] = {}

	# ---- Population section ----
	if not state.has("population"):
		state["population"] = defaults["population"].duplicate(true)
	var population: Dictionary = state["population"]
	# JS might have "pop" or "population" as a number
	if state.has("pop") and not population.has("total"):
		population["total"] = int(state["pop"])
		state.erase("pop")
	if not population.has("total"):
		population["total"] = 0
	if not population.has("happiness"):
		population["happiness"] = 60.0
	if not population.has("requests"):
		population["requests"] = []

	# ---- Progression section ----
	if not state.has("progression"):
		state["progression"] = defaults["progression"].duplicate(true)
	var progression: Dictionary = state["progression"]
	# JS used "cityLevel" (camelCase)
	if state.has("cityLevel"):
		progression["city_level"] = int(state["cityLevel"])
		state.erase("cityLevel")
	if progression.has("cityLevel"):
		progression["city_level"] = int(progression["cityLevel"])
		progression.erase("cityLevel")
	if not progression.has("city_level"):
		progression["city_level"] = 1
	# JS used "prestigeStars"
	if state.has("prestigeStars"):
		progression["prestige_stars"] = int(state["prestigeStars"])
		state.erase("prestigeStars")
	if progression.has("prestigeStars"):
		progression["prestige_stars"] = int(progression["prestigeStars"])
		progression.erase("prestigeStars")
	if not progression.has("prestige_stars"):
		progression["prestige_stars"] = 0

	_ensure_defaults(progression, {
		"total_prestiges": 0,
		"total_upgrades_done": 0,
		"total_buildings_placed": 0,
		"tutorial_step": 0,
	})

	# ---- Pressure section ----
	if not state.has("pressure"):
		state["pressure"] = defaults["pressure"].duplicate(true)
	_ensure_defaults(state["pressure"], defaults["pressure"])

	# ---- Events section ----
	if not state.has("events"):
		state["events"] = defaults["events"].duplicate(true)
	var events: Dictionary = state["events"]
	if not events.has("timer"):
		events["timer"] = 30.0
	if not events.has("active_event"):
		events["active_event"] = null
	if not events.has("history"):
		events["history"] = []

	# ---- Meta section ----
	if not state.has("meta"):
		state["meta"] = defaults["meta"].duplicate(true)
	_ensure_defaults(state["meta"], defaults["meta"])

	# ---- Set schema version ----
	state["schema_version"] = SaveSchemaV1.VERSION

	return true


## Fill in missing keys from defaults.
static func _ensure_defaults(target: Dictionary, defaults: Dictionary) -> void:
	for key: String in defaults:
		if not target.has(key):
			target[key] = defaults[key]
