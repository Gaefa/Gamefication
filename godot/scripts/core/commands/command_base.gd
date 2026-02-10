## command_base.gd -- Abstract base class for all game commands.
## Commands encapsulate a single state-mutating action that can be
## validated, executed, and (potentially) undone.  All concrete commands
## must override execute().
class_name CommandBase


## Execute the command against the current game state.
## Returns true if the command succeeded, false if validation failed
## or the command could not be applied for any reason.
## Subclasses MUST override this method.
func execute(state: Dictionary, hex_grid: HexGrid, spatial_index: SpatialIndex) -> bool:
	push_warning("CommandBase.execute() called on abstract base -- override in subclass.")
	return false
