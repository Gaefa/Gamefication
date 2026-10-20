extends Node
## One panel at a time. Every centred or full-screen panel (water, season, log, diary,
## help, city, governance, settings, the pause menu) announces itself here when it opens:
## the panel before it closes, Escape closes the current one, and the day waits while a
## panel is open, the way it waits for the Desk. Also the one place panels and notices
## get their short fade-in, so nothing on screen pops.

var _open_id: String = ""
var _close: Callable = Callable()
var _paused_by_panel: bool = false


## Is a panel open (any, or the one with this id)?
func is_open(id: String = "") -> bool:
	return _open_id != "" if id == "" else _open_id == id


## A panel has just become visible. `close` hides it again (and calls closed()).
func opened(id: String, close: Callable) -> void:
	if _open_id != "" and _open_id != id and _close.is_valid():
		var previous: Callable = _close
		_open_id = ""
		previous.call()
	_open_id = id
	_close = close
	if SimulationRunner.run_active and SimulationRunner.current_phase == SimulationRunner.Phase.DAY \
			and not SimulationRunner.card_open and not SimulationRunner.paused:
		SimulationRunner.paused = true
		_paused_by_panel = true


## A panel has just been hidden. The day resumes if it was this layer that paused it.
func closed(id: String) -> void:
	if _open_id != id:
		return
	_open_id = ""
	_close = Callable()
	if _paused_by_panel:
		_paused_by_panel = false
		if SimulationRunner.current_phase == SimulationRunner.Phase.DAY and not SimulationRunner.card_open:
			SimulationRunner.paused = false


## Escape: closes the open panel. True when there was one to close.
func close_current() -> bool:
	if _open_id == "" or not _close.is_valid():
		return false
	_close.call()
	return true


## A short fade and a small rise instead of popping into place. Safe to call again
## while a previous reveal is still running.
func reveal(control: Control, duration: float = 0.12, rise: float = 6.0) -> void:
	if control.has_meta("ui_reveal"):
		var previous: Tween = control.get_meta("ui_reveal") as Tween
		if previous != null and previous.is_valid():
			previous.kill()
			control.position = control.get_meta("ui_rest") as Vector2
	var rest: Vector2 = control.position
	control.set_meta("ui_rest", rest)
	control.modulate.a = 0.0
	var tween: Tween = control.create_tween().set_parallel(true)
	tween.tween_property(control, "modulate:a", 1.0, duration)
	if rise > 0.0:
		control.position = rest + Vector2(0.0, rise)
		tween.tween_property(control, "position", rest, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	control.set_meta("ui_reveal", tween)
