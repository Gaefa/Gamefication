# Pixel City Builder: Architecture Optimization + Godot Migration Plan (v0.1)

## 1. Цель
Сделать кодовую базу масштабируемой по функционалу и производительности, а затем безопасно переехать с web runtime на Godot без потери фич и баланса.

Ключевые требования:
- не раздувать код до "40k, где реально работает 5k";
- отделить чистую симуляцию от UI/рендера/платформы;
- обеспечить детерминизм и тестируемость;
- подготовить переиспользуемую data model для web и Godot.

## 2. Текущее состояние (по коду проекта)

## 2.1 Наблюдения
1. Логика сильно центрирована в `src/main.js` (UI, input, loop, orchestration).
2. Глобальный mutable state (`STATE`) используется напрямую почти всеми модулями.
3. Есть параллельная legacy-ветка `game.js` (2582 строк), создающая риск дублирования и рассинхрона.
4. Экономика и пассивные статы часто обходят всю карту повторно, что ограничит масштаб.
5. DOM-рендер в web-UI вызывается каждый кадр, даже когда данные не изменились.
6. Save/load требует строгой схемы и нормализации (иначе на росте функционала вырастут баги миграции сейвов).

## 2.2 Главные архитектурные риски
1. Tight coupling между simulation, UI и platform APIs.
2. Отсутствие четких границ слоев.
3. Ориентация на прямые мутации вместо команд и редьюсеров домена.
4. Недостаток инструментов контроля производительности (профайлинг/бенч/регресс).

## 3. Целевая архитектура (до Godot)

## 3.1 Слои
1. `Core Simulation` (чистый домен, без DOM/Canvas/Audio/localStorage).
2. `Application Layer` (сценарии: build, upgrade, tick, crisis resolve).
3. `Adapters` (web renderer, web input, save backend, audio backend).
4. `Content` (JSON/таблицы баланса, ивенты, биомы, кризисы).

Правило:
- Core не знает о платформе.
- Adapters не содержат бизнес-логики.

## 3.2 Разделение по пакетам (предложение)
- `src/core/`
  - `state/` (структуры состояния, validators)
  - `systems/` (economy, citizens, pressure director, events, progression)
  - `commands/` (Build, Upgrade, Bulldoze, PolicyChange, etc.)
  - `rng/` (seeded RNG provider)
- `src/app/`
  - `game_orchestrator.js`
  - `tick_scheduler.js`
  - `session_controller.js`
- `src/adapters/web/`
  - `render/`
  - `ui/`
  - `input/`
  - `storage/`
  - `audio/`
- `src/content/`
  - `buildings.json`
  - `events.json`
  - `difficulty.json`

## 3.3 Контракт состояния
Ввести версионируемую схему:
- `schemaVersion`;
- нормализация всех коллекций;
- миграторы сейвов `vN -> vN+1`;
- валидация при загрузке (мягкий fallback + лог ошибок).

## 3.4 DLC-архитектура (чтобы проект не поехал)

## 3.4.1 Принцип
Каждое DLC подключается как модуль расширения через стабильные extension points.  
Запрещено: прямая правка core-систем под конкретный DLC.

## 3.4.2 Контракт DLC-модуля
Каждый DLC содержит manifest:
- `dlcId`, `version`, `requiredCoreVersion`;
- `capabilities` (что добавляет: systems/content/ui/save);
- `contentBundles` (events/buildings/policies/scenarios/biomes);
- `saveNamespace` (например, `dlc_governance`).

Core на старте:
1. читает manifest;
2. проверяет совместимость;
3. регистрирует capability;
4. включает feature flags.

## 3.4.3 Extension points (обязательные)
- `TickHooks`: before/after tick фаз.
- `PressureHooks`: модификаторы индекса давления.
- `EventCatalogHooks`: добавление ивентов и условий.
- `CitizenNeedHooks`: новые потребности и формулы удовлетворенности.
- `UISlotHooks`: вкладки/виджеты без правки core-HUD.
- `SaveHooks`: чтение/запись namespaced данных DLC.

## 3.4.4 Архитектурные решения по DLC-типам
1. `Crisis Packs`
- Модуль: `HazardSystemPlugin`.
- Интеграция: через `EventCatalogHooks` + `PressureHooks`.
- Изоляция: хранить только свои параметры катастроф в `saveNamespace`.

2. `Biome Pack`
- Модуль: `BiomeProviderPlugin`.
- Интеграция: worldgen pipeline (`MapGenStage`), без правки economy core.
- Изоляция: biome rules через data tables, не через hardcode в системах.

3. `Scenario Pack`
- Модуль: `ScenarioRuntimePlugin`.
- Интеграция: сценарный DSL/JSON + objective engine.
- Изоляция: сценарий не меняет глобальные формулы, только конфигурирует их.

4. `Governance & Belief Expansion`
- Модуль: `GovernancePlugin` + `BeliefPlugin`.
- Интеграция:
  - `CitizenNeedHooks` для политических/идеологических ожиданий;
  - `PressureHooks` для легитимности, протестов и радикализации;
  - `TickHooks` для политики и влияния доктрин.
- Изоляция:
  - технологии, политики и идеологии хранятся в отдельных графах/таблицах;
  - core получает только агрегированные модификаторы через capability API.

5. `Cosmetic Pack`
- Модуль: `VisualThemePlugin`.
- Интеграция: только renderer/UI theme registry.
- Изоляция: полный запрет на изменение simulation state.

## 3.4.5 Save/Load для DLC
- Сейв делится на:
  - `coreState`;
  - `dlcStates[dlcId]`.
- Если DLC отключен:
  - `coreState` грузится штатно;
  - `dlcState` паркуется, не ломая сессию.
- При повторном включении DLC:
  - state rehydration по `saveNamespace`.

## 3.4.6 Governance & Belief: структура модуля
Рекомендуемая декомпозиция:
- `TechTreeSystem` (граф технологий, prerequisites, cost, unlocks).
- `PolicyEngine` (активные политики, бюджетные режимы, законы).
- `BeliefDynamicsSystem` (фракции, лояльность, напряжение, протестный риск).
- `LegitimacyIndexSystem` (агрегатор общественного доверия).

Контракт output в core:
- `policyModifiers` (экономика/сервисы/риски);
- `socialPressureModifiers` (давление и шанс кризисов);
- `citizenNeedWeights` (перевес ожиданий групп).

## 4. Performance-стратегия

## 4.1 Что оптимизировать в первую очередь
1. Убрать пер-кадровые полные обновления DOM, перейти на `dirty flags` + throttling.
2. Уменьшить количество полных проходов по сетке в тике.
3. Вынести тяжелые выборки радиусов в spatial index/cache.
4. Снизить число временных аллокаций в горячих циклах.

## 4.2 Практические решения
1. `Spatial Index`
- поддерживать индексы по типам зданий (`roads`, `parks`, `power`, `water_tower`, etc.);
- для аур использовать предварительные buckets/chunks вместо полного обхода сетки.

2. `Tick Phasing`
- разбить тик на фазы:
  - resources;
  - citizens;
  - pressure;
  - events;
  - cleanup.
- часть дорогих систем считать не каждую секунду, а раз в `N` тиков.

3. `UI Budget`
- HUD: 5-10 Hz;
- статистика и графики: 1-2 Hz;
- minimap: только при изменениях карты/камеры.

4. `Data Layout`
- terrain хранить в typed arrays;
- для зданий: индексируемый массив + occupancy map;
- избегать хранения лишних строк в горячих структурах.

5. `Deterministic RNG`
- единый генератор случайностей для core;
- запрет на прямой `Math.random()` в доменных системах.

6. `Observability`
- счетчики времени систем;
- budget alerts (например, tick > 8 ms);
- regression benchmark на фиксированном сейве.

## 5. Управление кодовой базой (чтобы не раздувалась)

## 5.1 Правила
1. Ни одна новая фича не добавляется в monolithic `main.js`.
2. Любая новая механика идет через `command -> system -> state patch`.
3. Один модуль = одна ответственность.
4. Все конфиги баланса только data-driven (`src/content`), не hardcode в системах.

## 5.2 Политика legacy
1. `game.js` пометить как архив и исключить из активной разработки.
2. Добавить `docs/legacy/` и зафиксировать статус.
3. Все изменения только в новой архитектуре.

## 6. План миграции в Godot (без big-bang)

## 6.1 Принцип миграции
Сначала стабилизируем и отделяем core, затем переносим адаптеры/представление в Godot.

## 6.2 Этапы
1. `Stage A: Core extraction (web)`
- вынести симуляцию в `src/core`;
- закрыть parity-тестами с текущим поведением.

2. `Stage B: Data contract`
- перенести `config.js` в JSON контент;
- зафиксировать schemaVersion и миграторы.

3. `Stage C: Godot prototype`
- Godot проект читает тот же контент JSON;
- реализует только: map render, input, fixed tick, save/load.

4. `Stage D: Feature parity`
- перенос систем по порядку:
  - economy;
  - progression;
  - events/pressure;
  - citizens;
  - ui panels.

5. `Stage E: Switch-over`
- freeze web feature-dev;
- закрыть parity checklist;
- объявить Godot как primary runtime.

## 6.3 Godot архитектура (рекомендуемая)
1. `Autoload`:
- `GameStateStore`;
- `SimulationRunner`;
- `ContentRegistry`;
- `SaveService`.

2. `Nodes`:
- `WorldRoot` (TileMap/terrain);
- `BuildingLayer` (MultiMeshInstance2D/TileMapLayer);
- `HudRoot` (Control UI);
- `EventOverlay`.

3. `Loop`
- simulation update в fixed timestep (`_physics_process`) с аккумулятором;
- render/UI отдельно от simulation.

4. `Data`
- JSON контент импортится как `Resource` кэш на старте;
- сейвы: бинарный или JSON с versioned schema.

## 6.4 Техстек в Godot
- Язык: GDScript для скорости итерации, C# только для CPU-hotspots.
- Рендер:
  - terrain через TileMapLayer;
  - массовые здания через MultiMesh;
  - эффекты катастроф отдельным FX-слоем.
- Профайлинг: встроенный Godot profiler + capture baseline на stress-сейвах.

## 7. Дорожная карта (12 недель)
1. Недели 1-2:
- core boundaries;
- save schema versioning;
- запрет new logic в `main.js`.
2. Недели 3-4:
- spatial index;
- dirty UI updates;
- perf baseline + bench сценарии.
3. Недели 5-6:
- pressure director v1 и кризисы на новой архитектуре.
4. Недели 7-8:
- Godot skeleton + загрузка контента + fixed tick.
5. Недели 9-10:
- migration economy/progression + parity tests.
6. Недели 11-12:
- migration UI/events/save + release candidate.

## 7.1 Дорожная карта DLC-архитектуры (дополнение)
1. Сперва ввести plugin contracts и save namespaces.
2. Затем портировать `Crisis Pack` как первый "тестовый" DLC-модуль.
3. После стабилизации контрактов внедрять `Governance & Belief`.
4. Только после этого масштабировать на Biome/Scenario packs.

## 8. Definition of Done для переезда
1. Все core-системы не зависят от web API.
2. Сейвы мигрируются по версиям без потери прогресса.
3. Godot build имеет feature parity по gameplay.
4. Производительность:
- tick budget стабилен в целевом стресс-сценарии;
- UI не обновляется без изменений данных.
5. Legacy `game.js` исключен из рабочей ветки разработки.
