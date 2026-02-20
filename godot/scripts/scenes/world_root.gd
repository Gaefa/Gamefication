## world_root.gd -- Container for all world rendering layers.
## Holds references to terrain, building, overlay, and FX layers.
extends Node2D


var _orchestrator: GameOrchestrator = null
var _hex_size: float = 32.0


# ------------------------------------------------------------------
# Setup (called by main.gd)
# ------------------------------------------------------------------

func setup(orchestrator: GameOrchestrator, hex_size: float) -> void:
	_orchestrator = orchestrator
	_hex_size = hex_size

	# Pass down to child layers
	var terrain_layer := $HexTerrainLayer
	if terrain_layer and terrain_layer.has_method("setup"):
		terrain_layer.setup(orchestrator, hex_size)

	var building_layer := $BuildingLayer
	if building_layer and building_layer.has_method("setup"):
		building_layer.setup(orchestrator, hex_size)

	var overlay_layer := $OverlayLayer
	if overlay_layer and overlay_layer.has_method("setup"):
		overlay_layer.setup(orchestrator, hex_size)

	var fx_layer := $FxLayer
	if fx_layer and fx_layer.has_method("setup"):
		fx_layer.setup(orchestrator, hex_size)


## Refresh all rendering layers (called after ticks or state changes).
func refresh() -> void:
	var terrain_layer := $HexTerrainLayer
	if terrain_layer and terrain_layer.has_method("refresh"):
		terrain_layer.refresh()

	var building_layer := $BuildingLayer
	if building_layer and building_layer.has_method("refresh"):
		building_layer.refresh()

	var overlay_layer := $OverlayLayer
	if overlay_layer and overlay_layer.has_method("refresh"):
		overlay_layer.refresh()
