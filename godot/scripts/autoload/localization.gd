extends Node
## Lightweight localization facade for game UI/content.
## Supports English and Russian from content/base/localization.json.

signal locale_changed(locale: String)

const CONTENT_PATH := "res://content/base/localization.json"
const DEFAULT_LOCALE := "en"
const SUPPORTED_LOCALES: Array[String] = ["en", "ru"]

var current_locale: String = DEFAULT_LOCALE
var _strings: Dictionary = {}


func _ready() -> void:
	_load_strings()
	var engine_locale := TranslationServer.get_locale().substr(0, 2).to_lower()
	set_locale(engine_locale if SUPPORTED_LOCALES.has(engine_locale) else DEFAULT_LOCALE, false)


func set_locale(locale: String, emit_signal: bool = true) -> void:
	if not SUPPORTED_LOCALES.has(locale):
		locale = DEFAULT_LOCALE
	current_locale = locale
	TranslationServer.set_locale(locale)
	if emit_signal:
		locale_changed.emit(current_locale)


func toggle_locale() -> void:
	set_locale("ru" if current_locale == "en" else "en")


func t(key: String, fallback: String = "") -> String:
	var entry: Dictionary = _strings.get(key, {})
	if entry.has(current_locale):
		return entry[current_locale] as String
	if entry.has(DEFAULT_LOCALE):
		return entry[DEFAULT_LOCALE] as String
	return fallback if fallback != "" else key


func _load_strings() -> void:
	if not FileAccess.file_exists(CONTENT_PATH):
		push_warning("Localization: file not found: %s" % CONTENT_PATH)
		return
	var file := FileAccess.open(CONTENT_PATH, FileAccess.READ)
	if file == null:
		push_warning("Localization: cannot open %s" % CONTENT_PATH)
		return
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("Localization: JSON parse error: %s" % json.get_error_message())
		return
	if json.data is Dictionary:
		_strings = json.data as Dictionary
