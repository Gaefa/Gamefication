## save_schema_v1.gd -- Defines the canonical shape of a v1 save file.
## Used by SaveValidator to verify save integrity and by SaveMigrator
## to transform older saves into the current format.
class_name SaveSchemaV1


## Current schema version.
const VERSION: int = 1


## Return a fresh default state dictionary conforming to schema v1.
## This is used as a reference for validation and migration.
static func default_state() -> Dictionary:
	return {
		"schema_version": VERSION,
		"world": {
			"grid_size": 64,
			"seed": 0,
			"buildings": {},
			"terrain_generated": false,
		},
		"economy": {
			"resources": {},
			"caps": {},
			"production_rates": {},
			"consumption_rates": {},
			"buffs": [],
		},
		"population": {
			"total": 0,
			"happiness": 60.0,
			"requests": [],
		},
		"progression": {
			"city_level": 1,
			"prestige_stars": 0,
			"total_prestiges": 0,
			"total_upgrades_done": 0,
			"total_buildings_placed": 0,
			"tutorial_step": 0,
		},
		"pressure": {
			"index": 0.0,
			"phase": 0,
			"issue_count": 0,
			"decay_rate": 0.01,
		},
		"events": {
			"timer": 30.0,
			"active_event": null,
			"history": [],
		},
		"meta": {
			"created_at": 0.0,
			"last_saved_at": 0.0,
			"play_time": 0.0,
			"tick_count": 0,
			"version": "0.1.0",
		},
	}


## Return the list of required top-level keys.
static func required_sections() -> Array:
	return ["world", "economy", "population", "progression", "pressure", "events", "meta"]


## Return the required keys for each section.
static func required_keys() -> Dictionary:
	return {
		"world": ["grid_size", "seed", "buildings"],
		"economy": ["resources", "caps"],
		"population": ["total", "happiness"],
		"progression": ["city_level", "prestige_stars"],
		"pressure": ["index", "phase"],
		"events": ["timer"],
		"meta": ["play_time", "tick_count"],
	}


## Return the type expectations for building entries.
## Each building in world.buildings should conform to this shape.
static func building_schema() -> Dictionary:
	return {
		"type": TYPE_STRING,
		"level": TYPE_INT,
	}
