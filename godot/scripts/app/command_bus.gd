class_name CommandBus
## Routes and executes commands. Keeps a history for potential undo.

var _ctx: Dictionary = {}
var _history: Array = []


func set_context(ctx: Dictionary) -> void:
	_ctx = ctx


func execute(cmd: CommandBase) -> CommandBase:
	cmd.execute(_ctx)
	if cmd.success:
		_history.append(cmd)
	if cmd.message != "":
		EventBus.toast_requested.emit(cmd.message, 3.0)
	return cmd


func clear_history() -> void:
	_history.clear()
