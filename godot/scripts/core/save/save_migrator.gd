class_name SaveMigrator
## Migrates save data between schema versions.

static func migrate(data: Dictionary) -> Dictionary:
	var version: int = 0
	if data.has("meta"):
		version = data.meta.get("schema_version", 0) as int
	elif data.has("schemaVersion"):
		version = data.schemaVersion as int

	if version == 0:
		data = _migrate_v0_to_v1(data)
	return data


static func _migrate_v0_to_v1(data: Dictionary) -> Dictionary:
	## Migrate from legacy JS format to v1.
	if not data.has("meta"):
		data["meta"] = {
			"playtime_sec": 0.0,
			"difficulty": "normal",
			"rng_seed": 12345,
			"schema_version": 1,
		}
	else:
		data.meta["schema_version"] = 1

	if not data.has("pressure"):
		data["pressure"] = {"index": 0.0, "phase": "calm", "active_policy": ""}

	if not data.has("events"):
		data["events"] = {"active": [], "cooldowns": {}}

	var economy: Dictionary = data.get("economy", {})
	if not economy.has("buffs"):
		economy["buffs"] = []
	if not economy.has("production"):
		economy["production"] = {}

	return data
