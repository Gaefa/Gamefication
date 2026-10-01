extends Node
## Dev tool: fails if the content has references the game cannot resolve (see
## ContentDB._validate_content). Run: Godot --headless --path godot res://tools/content_check.tscn


func _ready() -> void:
	for warning: String in ContentDB.content_warnings:
		print("  ", warning)
	print("=== CONTENT CHECK: %d problems ===" % ContentDB.content_warnings.size())
	get_tree().quit(1 if not ContentDB.content_warnings.is_empty() else 0)
