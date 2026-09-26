extends Node
## Headless save/load round-trip check (RELEASE_PLAN §2.4: load restores state tick-for-tick).
## Plays WARMUP ticks, snapshots the save exactly as SaveService writes it, plays COMPARE
## more ticks (reference); then loads the snapshot through the real migrate/validate path,
## plays the same COMPARE ticks, and diffs the two end states field by field.
##
## Run: Godot --headless --path <proj> res://tools/save_roundtrip.tscn
## Dev tool, not shipped.

const WARMUP_TICKS := 600
const COMPARE_TICKS := 450


var orch: GameOrchestrator  # held for the whole run so SimulationRunner's tick callback stays valid


func _ready() -> void:
	orch = GameOrchestrator.new()
	orch.new_game(12345, "appointed_administrator")
	for _i: int in range(WARMUP_TICKS):
		orch.tick_scheduler.run_tick()

	var snapshot: String = JSON.stringify(GameStateStore.to_save_dict(), "\t", false, true)  # same args as SaveService

	for _i: int in range(COMPARE_TICKS):
		orch.tick_scheduler.run_tick()
	var reference: Dictionary = _normalize(GameStateStore.to_save_dict())

	var migrated: Dictionary = SaveMigrator.migrate(JSON.parse_string(snapshot) as Dictionary)
	var errors: Array[String] = SaveValidator.validate(migrated)
	print("=== validation errors: %s ===" % str(errors))
	GameStateStore.load_from_dict(migrated)
	orch.load_game()
	for _i: int in range(COMPARE_TICKS):
		orch.tick_scheduler.run_tick()
	var restored: Dictionary = _normalize(GameStateStore.to_save_dict())

	var diffs: Array[String] = []
	_diff("", reference, restored, diffs)
	print("=== ROUND-TRIP: %d differing fields ===" % diffs.size())
	for d: String in diffs.slice(0, 40):
		print("  " + d)
	get_tree().quit()


func _normalize(d: Dictionary) -> Dictionary:
	# Compare in the representation the save actually uses (JSON: ints become floats).
	return JSON.parse_string(JSON.stringify(d)) as Dictionary


func _diff(path: String, a: Variant, b: Variant, out: Array[String]) -> void:
	if a is Dictionary and b is Dictionary:
		var keys: Dictionary = {}
		for k: Variant in (a as Dictionary).keys():
			keys[k] = true
		for k: Variant in (b as Dictionary).keys():
			keys[k] = true
		for k: Variant in keys.keys():
			_diff("%s/%s" % [path, str(k)], (a as Dictionary).get(k, "<missing>"), (b as Dictionary).get(k, "<missing>"), out)
	elif a is Array and b is Array:
		var aa: Array = a as Array
		var bb: Array = b as Array
		for i: int in range(maxi(aa.size(), bb.size())):
			_diff("%s[%d]" % [path, i], aa[i] if i < aa.size() else "<missing>", bb[i] if i < bb.size() else "<missing>", out)
	elif (a is float or a is int) and (b is float or b is int):
		if absf(float(a) - float(b)) > 0.0001:
			out.append("%s: %s != %s" % [path, str(a), str(b)])
	elif typeof(a) != typeof(b) or a != b:
		out.append("%s: %s != %s" % [path, str(a), str(b)])
