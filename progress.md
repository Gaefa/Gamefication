Original prompt: Build a city builder with pixel graphics.

## v1.0 - Original Prototype
- Single-file game.js (2582 lines)
- 20x20 grid, top-down view
- 17 building types, 14 resources
- City levels 1-7, prestige system
- localStorage save

## v2.0 - Major Overhaul (Current)

### Architecture
- Fully modular ES6 codebase (11 files in src/)
- config.js: All building/resource/level definitions
- state.js: Game state management
- economy.js: Resources, production, synergies
- progression.js: Levels, prestige, upgrades, game tick
- renderer.js: Isometric 2.5D canvas rendering
- mapgen.js: Procedural terrain generation (noise-based)
- events.js: Random city events
- sound.js: Procedural SFX via Web Audio API
- save.js: Multi-slot save/load with offline progress
- tutorial.js: Step-by-step tutorial system
- main.js: Entry point, input handling, UI rendering

### New Features
- **64x64 map** with camera scrolling (WASD/arrows) and mouse wheel zoom
- **Isometric (2.5D) rendering** with depth-correct overlap
- **Procedural terrain**: water, sand, grass, hills, forest, rock (island-shaped)
- **Terrain affects gameplay**: cost multipliers, production bonuses
- **Road network**: buildings require road connection to operate efficiently
- **Water infrastructure**: Water Tower building with coverage radius
- **Power network**: Power Plants boost buildings in radius
- **Day/night cycle** with visual tinting and window glow
- **Sound effects**: procedural SFX for build, bulldoze, upgrade, etc.
- **Statistics panel**: live graph of population, happiness, coins
- **3 save slots** with slot info display
- **Tutorial system**: step-by-step guidance for new players
- **Minimap** for navigation
- **Touch support** for mobile (drag to pan, pinch to zoom)
- **15 resources** (added water_res)
- **18 building types** (added Water Tower)
- **5 event types** (added Drought)

### Controls
- WASD/Arrows: Camera movement
- Mouse wheel: Zoom
- Shift+drag or middle-click: Pan camera
- Left click: Place building / Select
- Right click: Bulldoze
- 1-9: Quick tool select
- U: Upgrade, R: Repair, B: Bulldoze, O: Upgrade tree
- F: Fullscreen, M: Mute, P: Prestige

### Target Platforms
- iOS, Android (via web wrapper / Capacitor)
- Steam/GoG (via Electron or similar)

### Technical Notes
- Pure HTML5/Canvas + ES modules, no dependencies
- type="module" in package.json
- Serves via any static HTTP server
- Canvas renders full window, UI panels overlay
