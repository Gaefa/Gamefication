# Pixel City Builder: Project Scaling Architecture Blueprint (v1.0)

## 1. Цель документа
Зафиксировать целевую архитектуру всего проекта для масштабирования:
- по коду (без монолита и дублирования);
- по производительности (рост карты, систем, DLC);
- по платформам (web сейчас, Godot как основной runtime в будущем).

Документ собран на базе текущего состояния репозитория:
- active runtime: `src/*` + `index.html` + `style.css`;
- legacy runtime: `game.js`;
- продуктовые/монетизационные документы: `docs/*.md`.

## 2. Текущее состояние (as-is)

## 2.1 Что уже хорошо
1. Есть модульное разбиение в `src/` (config/state/economy/progression/renderer/events/save/sound/tutorial/main).
2. Вынесены игровые данные в `src/config.js`.
3. Есть офлайн-прогресс и многослотовые сейвы.
4. Есть отдельные документы по монетизации и миграции.

## 2.2 Ключевые ограничения
1. `src/main.js` перегружен orchestration/UI/input/render-flow.
2. Global mutable `STATE` доступен напрямую из большинства модулей.
3. Дублирование логики в `game.js` (legacy) повышает стоимость изменений.
4. Часть систем имеет full-grid/full-radius обходы в горячем пути.
5. Web UI обновляется слишком часто относительно реальной смены данных.

## 3. Архитектурные принципы (to-be)
1. `Core first`: доменная симуляция независима от платформы.
2. `Data-driven`: контент и баланс в таблицах/JSON, не в кодовых ветках.
3. `Deterministic simulation`: единый RNG и фиксированные тик-контракты.
4. `Feature isolation`: DLC/expansion через extension points, без правок ядра.
5. `Incremental performance`: оптимизация по бюджетам и профилю, не "на глаз".
6. `Backward compatibility`: versioned save schema + миграторы.

## 4. Целевая архитектура слоев

## 4.1 Layer model
1. `Domain Core`
- состояние, команды, симуляционные системы, директор давления, граждане, кризисы.
- не знает про DOM/Canvas/WebAudio/localStorage.

2. `Application Layer`
- orchestration сценариев, session lifecycle, fixed tick scheduler, command queue.

3. `Platform Adapters`
- web renderer/input/audio/storage;
- godot renderer/input/audio/storage.

4. `Content Layer`
- здания, ресурсы, технологии, политики, кризисы, сценарии, биомы, DLC manifests.

5. `Tooling/QA`
- профайлинг, тесты, migration checks, content validators.

## 4.2 Рекомендуемая структура каталогов
```text
src/
  core/
    state/
    commands/
    systems/
    events/
    pressure/
    citizens/
    progression/
    save_schema/
    rng/
  app/
    game_orchestrator.js
    tick_scheduler.js
    command_bus.js
    session_service.js
  adapters/
    web/
      render/
      input/
      ui/
      audio/
      storage/
    godot/              # зеркальные адаптеры при миграции
  content/
    base/
      buildings.json
      city_levels.json
      events.json
      resources.json
    dlc/
      <dlc-id>/
        manifest.json
        content/*.json
docs/
  architecture/
  product/
  migration/
```

## 5. Доменная модель

## 5.1 Состояние
Минимальные секции `GameState`:
1. `world` (map, terrain, occupancy, buildings).
2. `economy` (resources, caps, production modifiers).
3. `population` (needs, satisfaction, classes/factions).
4. `progression` (city level, prestige, win state).
5. `pressure` (phase, index, vulnerability weights).
6. `events` (active, queue, cooldowns).
7. `meta` (playtime, history, difficulty, enabled DLC).

## 5.2 Команды (вместо прямых мутаций)
Базовый набор:
- `PlaceBuilding`
- `Bulldoze`
- `UpgradeBuilding`
- `RepairBuilding`
- `ResolveEvent`
- `SetPolicy`
- `AdvanceTick`
- `StartNewGame`
- `LoadSlot/SaveSlot`

Поток:
`UI/Input -> CommandBus -> Domain Systems -> StatePatch -> UI dirty flags`.

## 6. Системы и порядок тика

## 6.1 Fixed tick contract
Симуляция должна идти в фиксированном шаге (например, 1 сек симуляции), независимо от FPS.

## 6.2 Tick pipeline
1. `PreTick` (cooldowns, timers).
2. `EconomySystem` (consumes/produces, caps).
3. `InfrastructureSystem` (road/power/water coverage + penalties).
4. `CitizenNeedsSystem` (потребности, удовлетворенность, миграция).
5. `PressureDirectorSystem` (index, phase, vulnerability).
6. `EventSystem` (spawn/resolve/aftereffects).
7. `ProgressionSystem` (levels, prestige, win checks).
8. `PostTick` (history, telemetry counters, dirty flags).

## 7. Контентная архитектура

## 7.1 Правило
Баланс/ивенты/технологии/политики должны загружаться из content-файлов с валидацией схем.

## 7.2 Контент-контракты
Каждая сущность содержит:
- `id`
- `version`
- `requirements/prerequisites`
- `effects/modifiers`
- `ui metadata`
- `tags` (для selection/filtering директором событий)

## 8. DLC/Expansion архитектура

## 8.1 Подключение
Каждый DLC поставляется как модуль:
- `manifest.json`
- `content bundles`
- `capabilities`
- `save namespace`.

## 8.2 Extension points (обязательные)
- `TickHooks`
- `PressureHooks`
- `EventCatalogHooks`
- `CitizenNeedHooks`
- `UISlotHooks`
- `SaveHooks`

## 8.3 Ограничение безопасности
DLC запрещено:
- мутировать core-состояние вне зарегистрированных контрактов;
- изменять общие формулы через скрытый hardcode;
- писать в `coreState` без namespace.

## 9. Performance-архитектура

## 9.1 Целевые бюджеты
1. Симуляционный тик: `<= 8 ms` на целевом stress-сценарии.
2. Рендер кадра (web): стабильный `60 FPS` в типовом городе.
3. UI обновления: не чаще логически необходимых частот (dirty-driven).

## 9.2 Техники
1. Spatial index по типам зданий и чанкам.
2. Инкрементальные пересчеты вместо постоянных full-grid проходов.
3. Typed arrays для terrain/occupancy.
4. Кэш аур и сетевого покрытия с инвалидаторами при изменениях.
5. Разделение частот:
- симуляция: fixed;
- UI: 5-10 Hz;
- heavy charts: 1-2 Hz.

## 10. Save/Load архитектура

## 10.1 Схема
```json
{
  "schemaVersion": 3,
  "coreState": {},
  "dlcStates": {
    "dlc_governance": {}
  }
}
```

## 10.2 Правила
1. Любое изменение схемы = новый мигратор `vN -> vN+1`.
2. Загрузка всегда идет через validator + normalizer.
3. Отключенный DLC не ломает загрузку core; его state паркуется.

## 11. UI/Rendering архитектура

## 11.1 Web (текущая платформа)
1. Canvas рендер мира отдельно от DOM HUD.
2. DOM подписывается на конкретные срезы state.
3. Обновление DOM по dirty flags, а не каждый кадр.

## 11.2 Godot (целевая платформа)
1. `Autoload` сервисы: `GameStateStore`, `SimulationRunner`, `ContentRegistry`, `SaveService`.
2. Рендер: TileMap/MultiMesh для мира и массовых объектов.
3. UI: Control-based, подписки на state events.

## 12. Качество и разработка

## 12.1 Тестовая стратегия
1. `Core unit tests` для систем и формул.
2. `Determinism tests` на фиксированном seed/state.
3. `Save migration tests` для каждой версии схемы.
4. `Golden scenario tests` (reference outcome на N тиков).
5. `Perf regression tests` (stress save replay).

## 12.2 Инженерные гейты
1. Новый функционал не добавляется в legacy `game.js`.
2. Каждая фича сопровождается:
- обновлением content schemas;
- тестами;
- заметкой в архитектурном/продуктовом doc.
3. Любая интеграция DLC проходит через capability-contract review.

## 13. План внедрения

## 13.1 Фаза A (stabilize web core)
1. Выделить `src/core` и `src/app`.
2. Убрать бизнес-логику из `src/main.js` в orchestrator + core systems.
3. Ввести versioned save schema.

## 13.2 Фаза B (scale features)
1. Добавить pressure/citizen/policy расширения в core.
2. Подключить DLC manifests и extension points.
3. Оптимизировать hot paths (spatial index + caches).

## 13.3 Фаза C (godot transition)
1. Поднять Godot shell, который читает тот же content contract.
2. Перенести адаптеры платформы (render/input/audio/storage).
3. Закрыть feature parity checklist.
4. Перевести Godot в primary runtime, web оставить как compatibility build.

## 14. Definition of Done
1. Core не зависит от web/godot API.
2. Legacy `game.js` исключен из активной фич-разработки.
3. Все DLC подключаются через единый контракт.
4. Сейвы мигрируются между версиями без потери прогресса.
5. Производительность соответствует бюджетам на целевых сценариях.
