## audio_manager.gd -- Manages audio playback using AudioStreamPlayer nodes.
## Provides methods for procedural SFX (stubs for now) and volume control.
class_name AudioManagerClass
extends Node

# ---- State ----
var _muted: bool = false
var _volume: float = 0.3   # 0.0 .. 1.0

# ---- Audio players (created at runtime) ----
var _sfx_player: AudioStreamPlayer = null
var _music_player: AudioStreamPlayer = null

# ------------------------------------------------------------------
# Lifecycle
# ------------------------------------------------------------------

func _ready() -> void:
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "SFXPlayer"
	_sfx_player.bus = &"Master"
	add_child(_sfx_player)

	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = &"Master"
	add_child(_music_player)

	_apply_volume()


# ------------------------------------------------------------------
# SFX methods (stubs -- wire AudioStreamGenerator or samples later)
# ------------------------------------------------------------------

func play_build() -> void:
	_play_sfx("build")


func play_bulldoze() -> void:
	_play_sfx("bulldoze")


func play_upgrade() -> void:
	_play_sfx("upgrade")


func play_repair() -> void:
	_play_sfx("repair")


func play_level_up() -> void:
	_play_sfx("level_up")


func play_prestige() -> void:
	_play_sfx("prestige")


func play_click() -> void:
	_play_sfx("click")


func play_error() -> void:
	_play_sfx("error")


func play_event() -> void:
	_play_sfx("event")


func play_win() -> void:
	_play_sfx("win")


# ------------------------------------------------------------------
# Volume & mute control
# ------------------------------------------------------------------

func toggle_mute() -> bool:
	_muted = not _muted
	_apply_volume()
	return _muted


func is_muted() -> bool:
	return _muted


func set_volume(v: float) -> void:
	_volume = clampf(v, 0.0, 1.0)
	_apply_volume()


func get_volume() -> float:
	return _volume


# ------------------------------------------------------------------
# Internal
# ------------------------------------------------------------------

func _apply_volume() -> void:
	var linear: float = 0.0 if _muted else _volume
	var db: float = linear_to_db(linear) if linear > 0.0 else -80.0
	if _sfx_player:
		_sfx_player.volume_db = db
	if _music_player:
		_music_player.volume_db = db


func _play_sfx(sfx_name: String) -> void:
	if _muted:
		return
	# TODO: Replace with actual audio generation / preloaded samples.
	# For now, generate a quick procedural beep using AudioStreamGenerator
	# or load from res://assets/sfx/{sfx_name}.wav if it exists.
	var sample_path: String = "res://assets/sfx/%s.wav" % sfx_name
	if ResourceLoader.exists(sample_path):
		var stream: AudioStream = load(sample_path)
		if stream and _sfx_player:
			_sfx_player.stream = stream
			_sfx_player.play()
			return

	# Fallback: generate a simple procedural tone
	_play_procedural_tone(sfx_name)


func _play_procedural_tone(sfx_name: String) -> void:
	# Create a short procedural beep using AudioStreamGenerator.
	# Different sfx_names get different frequencies for variety.
	var generator: AudioStreamGenerator = AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = 0.15

	if _sfx_player == null:
		return
	_sfx_player.stream = generator
	_sfx_player.play()

	var playback: AudioStreamGeneratorPlayback = _sfx_player.get_stream_playback()
	if playback == null:
		return

	# Pick frequency based on sfx name hash
	var freq_map: Dictionary = {
		"build": 440.0,
		"bulldoze": 220.0,
		"upgrade": 523.0,
		"repair": 392.0,
		"level_up": 659.0,
		"prestige": 880.0,
		"click": 600.0,
		"error": 180.0,
		"event": 349.0,
		"win": 784.0,
	}
	var freq: float = freq_map.get(sfx_name, 440.0)
	var sample_count: int = int(generator.mix_rate * 0.1)  # 100ms tone
	var phase: float = 0.0
	var increment: float = freq / generator.mix_rate

	for i: int in range(sample_count):
		# Envelope: quick fade-in (5%), sustain, quick fade-out (20%)
		var t: float = float(i) / float(sample_count)
		var envelope: float = 1.0
		if t < 0.05:
			envelope = t / 0.05
		elif t > 0.8:
			envelope = (1.0 - t) / 0.2

		var sample: float = sin(phase * TAU) * envelope * 0.4
		playback.push_frame(Vector2(sample, sample))
		phase = fmod(phase + increment, 1.0)
	# Tone generation complete.
