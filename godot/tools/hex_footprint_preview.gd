extends Node
## P7 projection review using the production renderer. Run with a real renderer:
## Godot --path godot --resolution 1280x900 res://tools/hex_footprint_preview.tscn -- out=/abs/dir [legacy]

const Buildings = preload("res://scripts/scenes/building_layer.gd")
const IDS := ["bld_shelter", "bld_well_pump", "bld_source_tower"]
const NAMES := ["shelter_t1", "well_pump_t1", "source_tower_old_t1"]
var _dir := "user://"
var _legacy := false

class Sample extends Buildings:
	var type_id: String
	var level := 0
	var adjacent := false
	var tile: Texture2D = preload("res://assets/tiles/tile_dust.png")
	func _draw() -> void:
		var coords: Array[Vector2i] = [Vector2i.ZERO]
		if adjacent:
			coords.append_array([Vector2i(1, 0), Vector2i(0, 1)])
		for coord: Vector2i in coords:
			var c := HexCoords.axial_to_pixel(coord)
			draw_texture_rect(tile, Rect2(c - Vector2(32, 24), Vector2(64, 48)), false)
		for coord: Vector2i in coords:
			_draw_building_sprite(HexCoords.axial_to_pixel(coord), type_id, level)
		# Actual cell outline over the sprite makes the footprint offset visible.
		for coord: Vector2i in coords:
			var points := PackedVector2Array()
			for i: int in 7:
				var a := deg_to_rad(float(i) * 60.0)
				points.append(HexCoords.axial_to_pixel(coord) + Vector2(cos(a) * 32, sin(a) * 32 * 0.75))
			draw_polyline(points, Color("f7de8e"), 0.4, true)

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			_dir = arg.trim_prefix("out=")
		elif arg == "legacy":
			_legacy = true
	SaveService.set("_autosave_timer", -1.0e12)
	SimulationRunner.paused = true
	if _legacy:
		for i: int in IDS.size():
			var def: Dictionary = ContentDB.get_building_def(IDS[i])
			for level: int in (def["sprites_by_level"] as Array).size():
				def["sprites_by_level"][level] = (def["sprites_by_level"][level] as String).replace("_hex.png", ".png")
			def.erase("footprint")
	var bg := ColorRect.new()
	bg.size = Vector2(1280, 900)
	bg.color = Color("302d28")
	add_child(bg)
	_label("P7 / %s / three projection trials" % ("BEFORE" if _legacy else "AFTER"), Vector2(30, 20), 25)
	_label("Production renderer at 4x and 1x | gold outline = cell boundary | bottom row = adjacent cells at 2x", Vector2(30, 58), 17)
	for i: int in IDS.size():
		var x: float = 205 + i * 420
		_label(NAMES[i], Vector2(x - 135, 103), 19)
		_add_sample(IDS[i], Vector2(x, 400), 4.0)
		_add_sample(IDS[i], Vector2(x, 580), 1.0)
		_add_sample(IDS[i], Vector2(x - 45, 760), 2.0, true)
	# All migrated levels use hex; legacy preview restores the original paths.
	var probe := Buildings.new()
	for type_id: String in IDS:
		assert(probe._uses_hex_footprint(ContentDB.get_building_def(type_id), 0) == not _legacy)
	for type_id: String in ["bld_shelter", "bld_well_pump"]:
		assert(probe._uses_hex_footprint(ContentDB.get_building_def(type_id), 1) == not _legacy)
		assert(probe._uses_hex_footprint(ContentDB.get_building_def(type_id), 2) == not _legacy)
	assert(not probe._uses_hex_footprint({}, 0))
	assert(probe._get_building_sprite("missing_building", 0) == null)
	probe.free()
	_capture.call_deferred()

func _add_sample(id: String, at: Vector2, zoom: float, adjacent: bool = false) -> void:
	var sample := Sample.new()
	sample.type_id = id
	sample.position = at
	sample.scale = Vector2.ONE * zoom
	sample.adjacent = adjacent
	add_child(sample)

func _label(text: String, at: Vector2, size: int) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	add_child(label)

func _capture() -> void:
	await get_tree().process_frame
	RenderingServer.force_draw(true)
	var path := _dir.path_join("hex_preview.png")
	var err := get_viewport().get_texture().get_image().save_png(path)
	print("HEX PREVIEW: ", path, "; saved=", err == OK)
	get_tree().quit(0 if err == OK else 1)
