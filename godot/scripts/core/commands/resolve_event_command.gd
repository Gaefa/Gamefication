class_name ResolveEventCommand extends CommandBase
## Resolves an active game event (accept or decline).

var event_id: String
var accept: bool


func _init(p_event_id: String, p_accept: bool) -> void:
	event_id = p_event_id
	accept = p_accept


func execute(ctx: Dictionary) -> void:
	var event_system: EventSystem = ctx.get("event_system") as EventSystem
	if event_system == null:
		message = "No event system"
		return
	var result: Dictionary = event_system.resolve_event(event_id, accept)
	success = result.get("success", false) as bool
	if success:
		message = "Event %s %s" % [event_id, "accepted" if accept else "declined"]
	else:
		message = result.get("reason", "Event action failed") as String
