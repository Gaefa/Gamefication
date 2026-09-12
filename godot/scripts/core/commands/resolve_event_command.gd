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
		message = Localization.t("ui.command.no_event_system", "No event system")
		return
	var result: Dictionary = event_system.resolve_event(event_id, accept)
	success = result.get("success", false) as bool
	if success:
		var action_key := "ui.command.event_accepted" if accept else "ui.command.event_declined"
		var action_fallback := "accepted" if accept else "declined"
		message = Localization.t("ui.command.event_resolved", "Event %s %s") % [event_id, Localization.t(action_key, action_fallback)]
	else:
		message = result.get("reason", Localization.t("ui.command.event_action_failed", "Event action failed")) as String
