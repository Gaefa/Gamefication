# Задание для агента: графика Ржавой Норы (визуальный проход Б)

Ты работаешь в репозитории `Gaefa/Gamefication`, ветка от `main` (после мёрджа PR #5 `codex/visual-a`). Игра — Godot 4.6, папка `godot/`. Задача: сгенерировать недостающие спрайты в стиле существующего набора, положить их в проект, подключить и проверить скриншотом. Полное ТЗ по стилю — `docs/ART_BRIEF_v0.3.md`; этот файл — пошаговый план работы по нему.

## 0. Референсы (уже в репозитории)

Стиль задают эти файлы. Прикладывай к каждому запросу генерации 3–4 из них (первые четыре — обязательно):

| Файл | Что показывает |
|---|---|
| `godot/assets/buildings/tiers/hut_t2.png` | жильё: ржавая крыша, дощатые стены, бочка, юбка грунта |
| `godot/assets/buildings/tiers/water_tower_t2.png` | водонапорка: ржавый металл, стальная ферма, синяя капля-датчик |
| `godot/assets/buildings/tiers/power_t1.png` | сарай с механизмом и трубой |
| `godot/assets/buildings/tiers/farm_t1.png` | грядка, мешки, пыльная земля |
| `godot/assets/buildings/tiers/warehouse_t1.png` | склад с навесом и ящиками (внимание: справа обрезок второго объекта — так делать НЕ надо) |
| `godot/assets/buildings/tiers/water_tower_t3.png` | крупный водный узел, серо-голубой металл |
| `docs/images/visual_pass_a_map.png` | как всё это выглядит на карте сейчас |

Каждый референс — 360×724, объект внизу холста, прозрачный фон, ромб основания 2:1.

## 1. Как генерировать

Инструмент: GPT Image (`gpt-image-1`) через API или ChatGPT. Параметры: `size 1024x1024`, `background transparent`, `quality high`, `output_format png`. Референсы передавать как входные изображения (edit/reference mode).

Промпт = БАЗА + строка ассета + `Avoid: НЕГАТИВ`.

БАЗА:
```
Isometric game building sprite, hand-painted illustration style matching the attached reference images.
2:1 diamond footprint, view from upper-left at ~30°, soft daylight from top-left, short warm shadow.
Post-collapse dry district: rusted corrugated iron, sun-bleached wood, cracked grey concrete, rope, tarp, barrels.
Palette: ochre, dusty khaki, rust orange, grey-blue metal; deep blue only as a small water accent.
Weathered but inhabited and maintained, retro-diesel industrial, no sci-fi, no neon, no people.
Single building centered on a transparent background, thin skirt of dusty ground around the base,
nothing else in frame, no cropped second object at the edges, no ground outside the diamond base, no text.
```

НЕГАТИВ:
```
photo, 3D render, pixel art, cartoon outline, lush green grass, forest, snow, night, glowing lights,
neon, people, vehicles, second building, cropped object at edge, white background, watermark, text, blur, long cast shadow
```

Уровни: сначала t1, затем t2 и t3 — **правкой** t1 (t1 как референс) с промптом `Same building, same angle, palette and footprint, upgraded: <что добавить>`. Не генерировать уровни с нуля.

Каждый результат проверять по чек-листу §5 ТЗ. Ключевые проверки скриптом (Pillow):
- альфа по краям холста = 0 (нет обрезков);
- непрозрачные пиксели одним связным блоком (нет второго объекта);
- нижняя граница силуэта в нижних 15 % холста.

## 2. Что генерировать — полный список с промптами

Имя файла → `godot/assets/buildings/tiers/<имя>.png`. Промпт — строка после БАЗЫ.

### P1 — здания без арта (13 файлов)

| Файл | Промпт |
|---|---|
| `solar_panel_t1` | Low frame of rusted pipes holding six dusty matte solar panels tilted toward the sun, a battery crate and a rag for wiping dust, small footprint. |
| `tool_workshop_t1` | Open-sided workshop lean-to: wooden posts, corrugated roof, workbench with an anvil and a vise, hand tools on the wall, a barrel of scrap. |
| `tool_workshop_t2` | (правка t1) upgraded: closed shed walls, a brick chimney with thin smoke, a pedal grinding wheel by the door, a rack of finished shovels and picks. |
| `tool_workshop_t3` | (правка t2) upgraded: a second bay with a taller chimney, a belt-driven drill press, crates of tools stacked outside, a small sign with a hammer symbol. |
| `lumber_yard_t1` | Sawhorses, a two-man saw, a small stack of dry grey logs, wood chips on dusty ground, a coil of rope. |
| `lumber_yard_t2` | (правка t1) upgraded: a pole shed over the log stack, a wheelbarrow, a second higher log pile. |
| `lumber_yard_t3` | (правка t2) upgraded: a belt-driven sawmill under the shed, tall stacked planks, a hand-cranked hoist. |
| `quarry_pit_t1` | Shallow open stone pit with stepped ledges cut into pale rock, two pickaxes, a wooden wheelbarrow loaded with grey stone, dust. |
| `quarry_pit_t2` | (правка t1) upgraded: a wooden chute from the pit edge, a hand hoist on a beam, a pile of cut stone blocks. |
| `quarry_pit_t3` | (правка t2) upgraded: a tripod winch over the pit, a small ore cart on short rails, a tool shed at the rim. |
| `source_tower_old_t1` | Tall abandoned water tower on a rusted steel lattice, dented tank with a peeling painted water-drop logo, broken ladder, dry cracked ground beneath, no water, no lights — a monument. |
| `source_tower_restored_t1` | (правка source_tower_old_t1) upgraded: patches of new grey metal on the tank, a new ladder, a connected pipe running down to the ground, a wet dark patch under a tap, the water-drop logo freshly repainted. |
| `company_ruin_t1` | Roofless ruined warehouse, exposed rafters, collapsed wall, rusted crates stamped with a water-drop logo, faded banner, a single dry shrub growing inside. |
| `company_office_t1` | Two-storey concrete office with boarded windows, a faded sign with a water-drop logo, an empty flagpole, cracked front steps, dust drifts against the wall. |

### P2 — тайлы земли (12 файлов)

Формат: PNG RGBA **256×192**, гекс плоской стороной вверх (flat-top), вписан по ширине, углы прозрачные. Промпт-база для тайлов другая:

```
Top-down isometric game terrain tile: a flat-top hexagon filling the canvas width, corners outside the hexagon fully transparent.
Hand-painted texture matching the attached reference images' palette (ochre, dusty khaki, rust, grey).
Even lighting, no objects, no buildings, no text, edges soft enough to tile with neighbours.
```

| Файл | Промпт |
|---|---|
| `tile_dust` | Trampled ochre dirt, fine cracks, a few small pebbles. |
| `tile_dry_bed` | Dry riverbed: cracked clay plates, lighter in the middle, darker rim. |
| `tile_salt_flat` | Salt flat: almost white crust with grey streaks. |
| `tile_clay_hill` | Rust-red clay hill: stepped relief, shadow on the lower face. |
| `tile_scrub` | Khaki dirt with tufts of stiff dry grass and one low thorny shrub. |
| `tile_rock` | Grey-brown bedrock with ridges, dust caught in the cracks. |
| `tile_<x>_dust` ×6 | (правка каждого) Same tile under a dust storm: warm rusty haze over everything, details softened, shadows shorter. |

### P3 — реквизит (10 файлов)

PNG RGBA **512×512**, ромб основания 2:1 в нижней части холста, объект по центру. Промпт-база = БАЗА зданий, но `Single small prop` вместо `Single building`.

| Файл | Промпт |
|---|---|
| `prop_pipe_straight` | A section of rusted half-metre pipe on two concrete supports, running along the long axis of the diamond base. |
| `prop_pipe_bend` | The same rusted pipe on concrete supports, turning 60 degrees, a bolted flange at the bend. |
| `prop_pipe_broken` | Rusted pipe with a torn open gap, edges bent outward, a dark rust stain on the ground. |
| `prop_sign_company` | Leaning wooden billboard on two posts with a faded water-drop company logo and unreadable worn lettering. |
| `prop_debris` | Pile of rusted scrap: corrugated sheets, a tyre, a dented barrel. |
| `prop_dry_well` | Abandoned stone well with a broken windlass, dry inside. |
| `prop_barrels` | Three or four barrels under a tarp held by rope, a bucket beside them. |
| `prop_tarp_tent` | A tarp awning on poles, a crate, a ring of stones for a fire, a bedroll. |
| `prop_leaflets` | A wooden post plastered with grey paper leaflets, some torn. |
| `prop_fence` | A leaning fence of poles and wire mesh along one edge of the diamond base. |

### P4 — замена дублей (12 файлов)

| Файл | Промпт |
|---|---|
| `well_pump_t1` | Stone well with a wooden windlass and a bucket, a trough, small footprint. |
| `well_pump_t2` | (правка t1) upgraded: a cast-iron hand pump column beside the well, a longer trough, a barrel. |
| `well_pump_t3` | (правка t2) upgraded: a small engine-driven pump under a tin roof, a small elevated tank, a pipe leading away. |
| `main_cistern_t1` | Low wide concrete cistern with a hatch on top, a ladder, a painted level mark on the wall, a tap with a barrel beneath. Squat, not tall. |
| `main_cistern_t2` | (правка t1) upgraded: a second tank joined by a pipe, a filling tap with a queue of barrels, a visible water level stripe. |
| `main_cistern_t3` | (правка t2) upgraded: a battery of three tanks on a low trestle, walkway with rails, gauge dials, a painted water-drop logo. |
| `shelter_t1` | One-room barrack of planks and corrugated iron, a curtain door, a barrel, laundry line. |
| `shelter_t2` | (правка t1) upgraded: an added room, a water tank on the roof, a porch. |
| `shelter_t3` | (правка t2) upgraded: a second storey with an outside gallery and stairs, two chimneys. |
| `admin_post_t1` | Small concrete administration block with a flagpole flying a plain deep-blue flag, a noticeboard, a doorstep. |
| `admin_post_t2` | (правка t1) upgraded: a second storey, a radio antenna, a covered entrance. |
| `admin_post_t3` | (правка t2) upgraded: an archive wing with narrow windows, a porch with columns, a bigger noticeboard. |

## 3. Подключение в проект

### P1 — здания
В `godot/content/base/buildings.json` заменить `sprites_by_level` и убрать `sprite_tint` там, где появился свой спрайт:

| id здания | `sprites_by_level` | `sprite_tint` |
|---|---|---|
| `bld_solar_panel` | `["res://assets/buildings/tiers/solar_panel_t1.png"]` | — |
| `bld_tool_workshop` | `[…/tool_workshop_t1.png, …_t2.png, …_t3.png]` | — |
| `bld_lumber_yard` | `[…/lumber_yard_t1.png, …_t2.png, …_t3.png]` | — |
| `bld_quarry_pit` | `[…/quarry_pit_t1.png, …_t2.png, …_t3.png]` | — |
| `bld_source_tower` | `[…/source_tower_old_t1.png]` | **удалить** |
| `bld_source_tower_restored` | `[…/source_tower_restored_t1.png]` | — |
| `bld_company_ruin` | `[…/company_ruin_t1.png]` | **удалить** |
| `bld_company_office` | `[…/company_office_t1.png]` | **удалить** |

Код подключения уже есть: `scripts/scenes/building_layer.gd` → `_get_building_sprite` (обрезка по силуэту, якорь по ромбу, y-сортировка). Ничего в коде менять не надо.

### P2 — тайлы
Сейчас земля рисуется цветными полигонами (`scripts/scenes/hex_terrain_layer.gd::_draw`). Нужно:
1. в `content/base/terrain.json` добавить каждому типу поле `"tile": "res://assets/tiles/tile_<id>.png"` и `"tile_dust": "…_dust.png"` (класть тайлы в `godot/assets/tiles/`);
2. в `_draw` для каждой клетки вместо `draw_colored_polygon` рисовать `draw_texture_rect(tex, Rect2(center - Vector2(HEX_SIZE, HEX_SIZE * ISO_Y), Vector2(HEX_SIZE * 2, HEX_SIZE * 2 * ISO_Y)))`, где `HEX_SIZE = 32`, `ISO_Y = 0.75` (из `scripts/core/hex/hex_coords.gd`); тонкую линию сетки оставить;
3. выбирать `tile_dust`, когда `GameStateStore.climate().season_id == "season_dust"`; перерисовывать по сигналу `EventBus.season_changed`;
4. текстуры кэшировать в словаре, как `_sprite_cache` в `building_layer.gd`; если у типа нет тайла — рисовать цветом, как сейчас (fallback).

### P3 — реквизит
Системы декора нет. Минимальная реализация:
1. `GameStateStore.world().decor.props` — массив `{"q", "r", "id"}`; заполнять в `scripts/app/game_orchestrator.gd::_bootstrap_company_traces` фиксированной раскладкой (без RNG!): трубы `prop_pipe_*` вдоль уже существующих `decor.pipes`, `prop_sign_company` у конторы, `prop_barrels` у цистерны, `prop_leaflets` у барака, `prop_debris` у руин;
2. рисовать в `hex_terrain_layer.gd` после тайлов (до зданий) через тот же приём, что `_draw_building_sprite`, ширина спрайта = `HEX_SIZE * 1.6`;
3. пропсы не занимают клетку: строительство поверх удаляет пропс из `decor.props`.

### P4 — дубли
Просто заменить пути в `buildings.json` для `bld_well_pump`, `bld_main_cistern`, `bld_shelter`, `bld_admin_post`.

## 4. Проверка (обязательно после каждого этапа)

Godot: `~/Downloads/Godot.app/Contents/MacOS/Godot` (macOS) или как в CI `.github/workflows/godot-export.yml`.

```bash
# ошибки скриптов (должно быть пусто)
Godot --headless --path godot --quit-after 240 2>&1 | grep -iE "SCRIPT ERROR|Parse Error|Failed to load"
# скриншот карты — смотреть глазами
Godot --path godot --resolution 1280x720 res://tools/screenshot.tscn -- out=/abs/dir   # даст menu.png и map.png
# логика не сломана
Godot --headless --path godot res://tools/balance_sim.tscn        # исходы A–F те же, что до изменений
Godot --headless --path godot res://tools/save_roundtrip.tscn     # "ROUND-TRIP: 0 differing fields"
```

Скриншот `map.png` после каждого этапа класть в `docs/images/visual_pass_b_<этап>.png` и прикладывать к PR.

## 5. Порядок и PR

1. P1 → PR «Visual pass B1: missing building sprites». Приложить скриншот.
2. P2 → PR «Visual pass B2: terrain tiles». Отдельный, потому что трогает рендер земли.
3. P3 → PR «Visual pass B3: props».
4. P4 → PR «Visual pass B4: replace shared sprites».

В каждом PR: список сгенерированных файлов, какие промпты не сработали с первого раза и что помогло, скриншот до/после. Коммиты GDScript — только табы; JSON — не переформатировать целиком, менять только нужные строки.
