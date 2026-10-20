class_name CommandBus
## Routes and executes commands.

var _ctx: Dictionary = {}


func set_context(ctx: Dictionary) -> void:
	_ctx = ctx


func execute(cmd: CommandBase) -> CommandBase:
	cmd.execute(_ctx)
	if cmd.message != "":
		EventBus.toast_requested.emit(cmd.message, 3.0)
	return cmd
