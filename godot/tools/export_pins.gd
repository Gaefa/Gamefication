extends SceneTree
## Regenerate the P5 raster assets from their editable vector sources:
## Godot --headless --path godot --script res://tools/export_pins.gd

func _initialize() -> void:
	var failures: int = 0
	for label: String in ["repair", "issue", "road", "power", "water", "stock", "pressure", "event"]:
		var source: String = "res://assets/ui/pins/src/pin_%s.svg" % label
		var destination: String = "res://assets/ui/pins/pin_%s.png" % label
		var image := Image.new()
		if image.load_svg_from_string(FileAccess.get_file_as_string(source), 4.0) != OK:
			push_error("Could not rasterize " + source)
			failures += 1
			continue
		image.resize(128, 128, Image.INTERPOLATE_LANCZOS)
		image.convert(Image.FORMAT_RGBA8)
		if image.save_png(destination) != OK:
			push_error("Could not save " + destination)
			failures += 1
	print("PINS EXPORT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
