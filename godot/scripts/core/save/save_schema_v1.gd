class_name SaveSchemaV1
## Reference schema for save version 1.
## Used by SaveValidator to verify save data integrity.

const VERSION := 1

const REQUIRED_SECTIONS: Array[String] = [
	"world", "economy", "population", "progression",
	"pressure", "events", "meta",
]

const WORLD_KEYS: Array[String] = ["map_radius", "terrain", "buildings"]
const ECONOMY_KEYS: Array[String] = ["resources", "caps", "production", "buffs"]
const POPULATION_KEYS: Array[String] = ["total", "happiness", "growth_rate"]
const PROGRESSION_KEYS: Array[String] = ["city_level", "prestige_stars", "prestige_count", "history"]
const PRESSURE_KEYS: Array[String] = ["index", "phase", "active_policy"]
const EVENTS_KEYS: Array[String] = ["active", "cooldowns"]
const META_KEYS: Array[String] = ["playtime_sec", "difficulty", "rng_seed", "schema_version"]
