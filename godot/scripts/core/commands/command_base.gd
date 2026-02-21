class_name CommandBase
## Abstract base for all game commands (Command pattern).

var success: bool = false
var message: String = ""


func execute(_ctx: Dictionary) -> void:
	push_error("CommandBase.execute() not overridden")


func undo(_ctx: Dictionary) -> void:
	pass  # Optional: not all commands support undo
