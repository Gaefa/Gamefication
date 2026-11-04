extends Node
## The sound of the district. Every clip is procedural (tools/gen_sfx.py): UI clicks, the
## Desk's paper and stamp, the map's thuds and clanks, the day's bells, and a wind loop per
## season. Two buses, "SFX" and "Ambient", with volumes kept in settings.cfg. Headless tool
## runs keep the dummy audio driver, so play() costs nothing there.

const SETTINGS_PATH := "user://settings.cfg"
const AUDIO_DIR := "res://assets/audio/"
const SFX := ["ui_click", "ui_open", "ui_close", "letter_open", "stamp", "build_place", "demolish",
	"repair", "build_fail", "issue", "day_start", "evening_bell", "alarm", "ending"]
const WIND := {"season_window": "wind_window", "season_dust": "wind_dust", "season_heat": "wind_heat"}
const POOL_SIZE := 6
const CLICK_GAP_MS := 40  # simulated input and double events never machine-gun the click

var sfx_volume: float = 0.8
var ambient_volume: float = 0.5

## Headless tool runs have a dummy driver that never mixes: a started stream would be
## reported as a leaked resource at exit, so they stay silent.
var _silent: bool = DisplayServer.get_name() == "headless"
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _ambient: AudioStreamPlayer
var _last_click_ms: int = 0


func _ready() -> void:
	_ensure_bus("SFX")
	_ensure_bus("Ambient")
	for key: String in SFX:
		_streams[key] = load(AUDIO_DIR + key + ".wav")
	for season: String in WIND:
		_streams[WIND[season]] = load(AUDIO_DIR + (WIND[season] as String) + ".wav")
	for i: int in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_players.append(player)
	_ambient = AudioStreamPlayer.new()
	_ambient.bus = "Ambient"
	add_child(_ambient)
	_load_settings()
	_apply_volumes()

	# Every button in the game clicks, including the ones built later.
	_hook_buttons(get_tree().root)
	get_tree().node_added.connect(_hook_buttons)

	EventBus.building_placed.connect(func(_c: Vector2i, _t: String) -> void: play("build_place"))
	EventBus.building_removed.connect(func(_c: Vector2i, _t: String) -> void: play("demolish"))
	EventBus.building_repaired.connect(func(_c: Vector2i) -> void: play("repair"))
	EventBus.building_damaged.connect(func(_c: Vector2i, _s: float) -> void: play("demolish"))
	EventBus.building_issue_added.connect(func(_c: Vector2i) -> void: play("issue"))
	EventBus.command_failed.connect(func(_m: String) -> void: play("build_fail"))
	EventBus.desk_opened.connect(func(_e: Array) -> void: play("letter_open"))
	EventBus.desk_option_selected.connect(func(_i: String, _o: int, _e: Dictionary, _c: Dictionary) -> void: play("stamp"))
	EventBus.desk_closed.connect(func() -> void: play("ui_close"))
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.critical_event_started.connect(func(_d: Dictionary) -> void: play("alarm"))
	EventBus.audit_completed.connect(func(_p: bool, _s: int) -> void: play("stamp"))
	EventBus.ending_triggered.connect(func(_i: String, _k: String) -> void: play("ending"))
	EventBus.season_changed.connect(func(season_id: String, _d: int, _l: int) -> void: _set_wind(season_id))
	EventBus.run_started.connect(func(_c: bool) -> void: _set_wind(GameStateStore.climate().get("season_id", "season_window") as String))
	_set_wind("season_window")


func _exit_tree() -> void:
	# A playing stream at exit is reported as a leaked resource; stop them before teardown.
	_ambient.stop()
	for player: AudioStreamPlayer in _players:
		player.stop()


func play(key: String) -> void:
	var stream: AudioStream = _streams.get(key) as AudioStream
	if stream == null or _silent:
		return
	for player: AudioStreamPlayer in _players:
		if not player.playing:
			player.stream = stream
			player.play()
			return
	# All six busy: the oldest is the first in the pool order; steal it.
	_players[0].stream = stream
	_players[0].play()


## The streams the pack is missing (rules_smoke checks that this is empty).
func missing() -> Array:
	var result: Array = []
	for key: String in SFX:
		if _streams.get(key) == null:
			result.append(key)
	for season: String in WIND:
		if _streams.get(WIND[season]) == null:
			result.append(WIND[season])
	return result


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()
	_save_settings()


func set_ambient_volume(value: float) -> void:
	ambient_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()
	_save_settings()


func _on_phase_changed(phase: String) -> void:
	if phase == "evening":
		play("evening_bell")
	elif phase == "day":
		play("day_start")


func _set_wind(season_id: String) -> void:
	var stream: AudioStream = _streams.get(WIND.get(season_id, "wind_window")) as AudioStream
	if stream == null or _silent or (_ambient.stream == stream and _ambient.playing):
		return
	_ambient.stream = stream
	_ambient.play()


func _hook_buttons(node: Node) -> void:
	if node is BaseButton and not (node as BaseButton).pressed.is_connected(_on_button_pressed):
		(node as BaseButton).pressed.connect(_on_button_pressed)
	for child: Node in node.get_children():
		_hook_buttons(child)


func _on_button_pressed() -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_click_ms < CLICK_GAP_MS:
		return
	_last_click_ms = now
	play("ui_click")


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


func _apply_volumes() -> void:
	for pair: Array in [["SFX", sfx_volume], ["Ambient", ambient_volume]]:
		var idx: int = AudioServer.get_bus_index(pair[0] as String)
		var volume: float = pair[1] as float
		AudioServer.set_bus_mute(idx, volume <= 0.001)
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(volume, 0.001)))


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	sfx_volume = clampf(config.get_value("audio", "sfx", sfx_volume) as float, 0.0, 1.0)
	ambient_volume = clampf(config.get_value("audio", "ambient", ambient_volume) as float, 0.0, 1.0)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("audio", "ambient", ambient_volume)
	config.save(SETTINGS_PATH)
