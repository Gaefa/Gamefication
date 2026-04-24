# Technical Design Document

## 1. Architecture Goal

Система должна выдержать рост до полноценного citybuilder без превращения в 40k строк, где работает 5k.

Главное правило: gameplay logic lives in systems and data, scenes render and route input.

## 2. Current Runtime Layers

### Autoloads

- `ContentDB`: loads JSON content.
- `GameStateStore`: single source of truth.
- `EventBus`: global signals.
- `SimulationRunner`: fixed tick driver.
- `SaveService`: save/load.
- `AudioManager`: audio facade.

### Core Systems

- `EconomySystem`;
- `InfrastructureSystem`;
- `ProgressionSystem`;
- `PressureSystem`;
- `EventSystem`;
- `IssueSystem`;
- `MaintenanceSystem`.

### Data Structures

- `HexGrid`;
- `SpatialIndex`;
- `CoverageMap`;
- `ResourceFlow`;
- `TransportGraph`;
- `AuraCache`.

### Scene Layer

- `main.gd`: bootstrap and global input;
- `hud_root.gd`: HUD and diagnostics;
- `hex_terrain_layer.gd`: terrain rendering;
- `building_layer.gd`: building rendering;
- `overlay_layer.gd`: ranges and selection;
- `fx_layer.gd`: effects.

## 3. Content-Driven Design

Content files:
- buildings;
- resources;
- terrain;
- events;
- city levels;
- tutorial;
- future: technologies;
- future: policies;
- future: scenarios;
- future: expansions.

Rules:
- content IDs are immutable after public saves exist;
- no hardcoded building lists in systems;
- modifiers should be data-driven;
- content validation must run before release builds.

## 4. Technology System

Base-game system.

Data:
- `id`;
- `label`;
- `description`;
- `tier`;
- `cost`;
- `requires`;
- `unlocks`;
- `modifiers`.

Runtime:
- `TechnologySystem` validates unlocks;
- `GameStateStore.progression.technologies` stores researched IDs;
- `ModifierResolver` exposes effects to economy, coverage, pressure and events.

No system should ask `if tech_id == ...` except migration/debug tools.

## 5. Policy System

Base-game system.

Data:
- `id`;
- `category`;
- `label`;
- `description`;
- `requirements`;
- `effects`;
- `upkeep`;
- `pressure_delta`;
- `citizen_demand_delta`;
- `cooldown`.

Runtime:
- one active policy per category or configurable slots;
- switching policy emits event and can cost resources;
- policies feed modifiers into economy, pressure, citizen demands and event weights.

## 6. Modifier Pipeline

Needed to prevent DLC/base features from hardcoding into every system.

Sources:
- buildings;
- adjacency;
- technologies;
- policies;
- events/buffs;
- difficulty;
- scenarios;
- future expansions.

Output:
- production multiplier;
- consumption multiplier;
- happiness delta;
- pressure delta;
- event weight multiplier;
- coverage radius multiplier;
- upkeep multiplier.

## 7. Save Schema

Save must be versioned.

Core sections:
- world;
- economy;
- population;
- progression;
- pressure;
- events;
- technologies;
- policies;
- scenarios;
- meta.

Rules:
- invalid critical schema fails load;
- migrations are explicit;
- expansion state is namespaced;
- missing optional systems get defaults.

## 8. Expansion Architecture

Expansions are not allowed to patch core directly.

Expansion manifest:
- id;
- version;
- dependencies;
- content packs;
- systems enabled;
- save namespace;
- compatibility version.

Valid expansion types:
- building packs;
- entertainment packs;
- transport packs;
- biome packs;
- scenario packs;
- megaproject packs.

Base-game only:
- core tech tree;
- core policies;
- core resource flow;
- core citizen demands;
- core pressure director.

## 9. Transport Expansion Direction

Rail/metro should be expansion-ready but not required for MVP.

Future systems:
- `RailNetwork`;
- `MetroNetwork`;
- station catchment areas;
- commute demand;
- freight capacity;
- transit congestion.

These systems must use extension points:
- coverage providers;
- transport providers;
- citizen demand modifiers;
- building unlocks.

## 10. Performance Targets

Desktop MVP:
- stable 60 FPS on medium map;
- fixed simulation tick independent from rendering;
- no full-map recalculation every frame.

Mobile target:
- 30 FPS on tablet;
- lower map radius;
- reduced FX;
- touch-optimized UI.

Optimization rules:
- use dirty flags for coverage;
- cache adjacency;
- avoid per-frame `GameStateStore.get_all_building_coords()` in rendering where possible;
- stress test with max buildings.

## 11. Validation

Add content validation command/script:
- all referenced resources exist;
- all building levels valid;
- event costs valid;
- no missing labels;
- no invalid transport modes;
- save schema version matches.

Godot checks:
- headless import;
- short runtime launch;
- export preset check.

## 12. Immediate Technical Tasks

1. Add `technologies.json` and `TechnologySystem`.
2. Add `policies.json` and `PolicySystem`.
3. Add `ModifierResolver`.
4. Wire modifiers into `EconomySystem`, `PressureSystem`, `CoverageMap`.
5. Add `scenarios.json` and `ScenarioSystem`.
6. Add content validation.
7. Prepare expansion manifest format for later DLC.
