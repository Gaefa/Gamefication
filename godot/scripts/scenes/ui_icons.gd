extends RefCounted
## Flat P6 vectors. Missing artwork leaves the localized text/system cursor usable.

const RESOURCES := {
	"res_money": "money", "coins": "money",
	"res_food": "food", "food": "food",
	"res_water_stockpile": "water", "water_res": "water",
	"res_wood": "wood", "wood": "wood",
	"res_stone": "stone", "stone": "stone",
	"res_tools": "tools", "tools": "tools",
}
const CATEGORIES := {
	"Infrastructure": "infrastructure", "Residential": "residential",
	"Production": "production", "Commercial": "commercial",
	"Culture": "culture", "Advanced": "advanced",
}
static var _cache: Dictionary = {}


static func texture(icon: String, folder: String = "icons") -> Texture2D:
	var path: String = "res://assets/ui/%s/%s.svg" % [folder, icon]
	if not _cache.has(path):
		_cache[path] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _cache[path] as Texture2D


static func bb(icon: String) -> String:
	if texture(icon) == null:
		return ""
	# Keep the icon with the first word when the HUD wraps in a narrow window.
	return "[img=18x18]res://assets/ui/icons/%s.svg[/img]\u00a0" % icon
