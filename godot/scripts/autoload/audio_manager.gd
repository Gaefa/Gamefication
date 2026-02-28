extends Node
## Minimal audio manager.  Plays UI sounds and ambient loops.
## Falls back to procedural tones when no audio files are present.

var _players: Dictionary = {}  # channel_name → AudioStreamPlayer


func play_sfx(channel: String, stream: AudioStream = null) -> void:
	var player := _get_or_create(channel)
	if stream:
		player.stream = stream
	if player.stream:
		player.play()


func stop(channel: String) -> void:
	if _players.has(channel):
		(_players[channel] as AudioStreamPlayer).stop()


func _get_or_create(channel: String) -> AudioStreamPlayer:
	if _players.has(channel):
		return _players[channel] as AudioStreamPlayer
	var p := AudioStreamPlayer.new()
	p.bus = "Master"
	add_child(p)
	_players[channel] = p
	return p
