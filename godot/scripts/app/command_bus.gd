## command_bus.gd -- Central dispatcher for all game commands.
## Validates and executes CommandBase subclasses against the live game state.
## Provides undo history for future use and emits signals through EventBus.
class_name CommandBus


## Maximum undo history depth.
const MAX_HISTORY: int = 50

## Executed command history (for future undo support).
var _history: Array = []

## Reference to the live HexGrid instance.
var _hex_grid: HexGrid = null

## Reference to the live SpatialIndex instance.
var _spatial_index: SpatialIndex = null

## Reference to the live AuraCache instance.
var _aura_cache: AuraCache = null

## Reference to the live TransportGraph instance.
var _transport_graph: TransportGraph = null


# ------------------------------------------------------------------
# Lifecycle
# ------------------------------------------------------------------

func _init(hex_grid: HexGrid, spatial_index: SpatialIndex,
		aura_cache: AuraCache, transport_graph: TransportGraph) -> void:
	_hex_grid = hex_grid
	_spatial_index = spatial_index
	_aura_cache = aura_cache
	_transport_graph = transport_graph


# ------------------------------------------------------------------
# Execute a command
# ------------------------------------------------------------------

## Execute a command.  Returns true if it succeeded.
func execute(command: CommandBase) -> bool:
	var state: Dictionary = GameStateStore.state
	if state.is_empty():
		push_warning("CommandBus: cannot execute command -- no active game state.")
		return false

	var ok: bool = command.execute(state, _hex_grid, _spatial_index)
	if not ok:
		return false

	# Record in history
	_history.append(command)
	if _history.size() > MAX_HISTORY:
		_history.pop_front()

	# Post-command invalidation
	_invalidate_caches_for(command)

	return true


# ------------------------------------------------------------------
# Cache invalidation after commands
# ------------------------------------------------------------------

func _invalidate_caches_for(command: CommandBase) -> void:
	# Determine what coord was affected (if any).
	var coord: Vector2i = Vector2i(-999, -999)
	if "q" in command and "r" in command:
		coord = Vector2i(command.q, command.r)

	if coord != Vector2i(-999, -999):
		# Invalidate aura cache around the affected hex.
		_aura_cache.invalidate_at(coord.x, coord.y, 10)
		# Mark transport graph dirty.
		_transport_graph.invalidate()
		# Emit coverage invalidation.
		EventBus.coverage_invalidated.emit()
		EventBus.network_invalidated.emit()


# ------------------------------------------------------------------
# History
# ------------------------------------------------------------------

## Return the number of commands in history.
func get_history_count() -> int:
	return _history.size()


## Clear all history.
func clear_history() -> void:
	_history.clear()
