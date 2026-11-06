extends Node
## Dev tool: fails if the content has references the game cannot resolve (see
## ContentDB._validate_content). Run: Godot --headless --path godot res://tools/content_check.tscn


func _ready() -> void:
	# Every chapter is checked with its own overlay; a chapter's mistakes name the chapter.
	var problems: int = 0
	for chapter_id: String in ContentDB.get_chapter_ids(true):
		ContentDB.set_chapter(chapter_id)
		for warning: String in ContentDB.content_warnings:
			print("  [%s] %s" % [chapter_id, warning])
		problems += ContentDB.content_warnings.size()
	print("=== CONTENT CHECK: %d problems ===" % problems)
	get_tree().quit(1 if problems > 0 else 0)
