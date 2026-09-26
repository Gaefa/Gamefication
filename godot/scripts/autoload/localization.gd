extends Node
## Lightweight localization facade for game UI/content.
## Supports English and Russian from content/base/localization.json.

signal locale_changed(locale: String)

const CONTENT_PATH := "res://content/base/localization.json"
const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_LOCALE := "ru"  # source language of the content; the fallback for any missing text
const SUPPORTED_LOCALES: Array[String] = ["en", "ru"]

var current_locale: String = DEFAULT_LOCALE
var _strings: Dictionary = {}


func _ready() -> void:
	_load_strings()
	# First launch follows the OS: Russian for a Russian system, English otherwise.
	# Settings (O) can switch and the choice is remembered.
	var saved_locale := _load_saved_locale()
	var os_locale: String = "ru" if OS.get_locale_language() == "ru" else "en"
	set_locale(saved_locale if SUPPORTED_LOCALES.has(saved_locale) else os_locale, false, false)


func set_locale(locale: String, emit_signal: bool = true, persist: bool = true) -> void:
	if not SUPPORTED_LOCALES.has(locale):
		locale = DEFAULT_LOCALE
	current_locale = locale
	TranslationServer.set_locale(locale)
	if persist:
		_save_locale(locale)
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


## Russian or English text written inline in code (cards and panels built in scripts).
func ru_en(ru: String, en: String) -> String:
	return en if current_locale == "en" and en != "" else ru


## Content fields are Russian; an English translation sits next to them as `<field>_en`
## (or behind a `<field>_key` in localization.json).
func content_text(def: Dictionary, field: String, fallback: String = "") -> String:
	var key_field := "%s_key" % field
	var key: String = def.get(key_field, "") as String
	var raw: String = def.get(field, fallback) as String
	if key != "":
		return t(key, raw)
	if current_locale == "en":
		var en: String = def.get("%s_en" % field, "") as String
		if en != "":
			return en
	return raw if raw != "" else fallback


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


func _load_saved_locale() -> String:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return ""
	var locale: String = config.get_value("ui", "locale", "") as String
	return locale if SUPPORTED_LOCALES.has(locale) else ""


func _save_locale(locale: String) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("ui", "locale", locale)
	var err := config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("Localization: cannot save locale settings: %s" % err)
