# Задание P7: здания и реквизит под шестиугольное основание (исправление перспективы)

Ветка от свежего `main`: `cod/visual-b7-hex-footprint`. Один PR со скриншотами до/после. Приоритет выше, чем у `TASK_CODEX_HEAT_SEASON.md`.

## 0. Проблема (из плейтеста)

Карта — **плоские гексы, вид сверху** (flat-top, сжатие по вертикали 0.75). Здания и реквизит нарисованы в **изометрии с ромбом 2:1** в основании, повёрнутой на 45°. Ромб не ложится на гекс: стены идут под чужим углом, «юбка» грунта торчит углами за клетку, здания выглядят приклеенными с другой карты. Тестер: «у моделек сломана перспектива».

Решение: перерисовать все используемые спрайты зданий и реквизита **в проекции сетки**, с шестиугольным основанием. Тайлы земли (P2), пины (P5) и иконки (P6) не трогать — они уже в правильной проекции.

## 1. Проекция — точно

- **Камера:** вид сверху-спереди, **без поворота вокруг вертикали** (здание стоит фасадом к зрителю, стены параллельны экрану и уходят прямо вверх). Никакой диагонали 45°.
- **Наклон:** вертикальное сжатие земли 0.75, то есть камера поднята на ≈ 49° над горизонтом (`asin(0.75)`). Видны крыша и передняя стена; боковых стен почти не видно.
- **Основание:** гекс плоской стороной вверх. При радиусе R: ширина `2R`, высота `√3·R·0.75 ≈ 1.30R`. Соотношение **ширина : высота ≈ 1.54 : 1**. Вершины: слева и справа по центру высоты, по две сверху и снизу.
- **Свет:** сверху-слева, как раньше. Тень короткая, вправо-вниз, **внутри гекса**.
- **Грунт:** «юбка» повторяет **гекс**, а не ромб и не овал; её край — в пределах гекса клетки (можно чуть рваный, но шестиугольный).

Схема холста 1024×1024:

```
      ┌──────────── 1024 ────────────┐
      │                              │
      │        (здание, вверх)       │
      │                              │
      │      ____________________    │  ← верхняя грань гекса
      │     /                    \   │
      │    /      основание       \  │  ширина гекса ≈ 800 px
      │    \       ≈ 800×520      /  │  высота гекса ≈ 520 px
      │     \____________________/   │  ← нижняя грань, ≈ 60 px от низа холста
      └──────────────────────────────┘
```

Центр гекса-основания: x = 512, y ≈ 704 (нижняя грань на y ≈ 964). Это якорь, по которому движок ставит спрайт на клетку.

## 2. Стиль

Тот же, что в `ART_BRIEF_v0.3.md`: рисованный, ржавое железо, выцветшее дерево, бетон, охра и ржавчина. Меняется **только проекция и форма основания**. Референсы стиля — текущие спрайты из `godot/assets/buildings/tiers/` (прикладывать 3–4 как образец материалов и палитры, но в промпте явно сказать, что ракурс другой). Референс проекции — любой тайл из `godot/assets/tiles/` (это и есть правильный гекс) и `docs/images/visual_pass_b_p2_tiles.png`.

База промпта (заменяет базу из `ART_TASK_CODEX.md`):

```
Top-down oblique game building sprite, hand-painted illustration, same materials and palette as the attached
building references (rusted corrugated iron, sun-bleached wood, cracked grey concrete, ochre dust).
CAMERA: straight-on three-quarter top-down view, about 50 degrees above the horizon, NOT rotated —
the front wall faces the viewer, walls are axis-aligned and rise straight up, no 45-degree isometric diamond.
BASE: the building stands on a FLAT-TOP HEXAGONAL plot (a wide hexagon, pointed left and right, flat edges
at top and bottom, about 1.54 times wider than tall), matching the attached hex tile exactly. The dusty
ground skirt is that hexagon — not a diamond, not an oval.
Soft daylight from top-left, short warm shadow inside the hexagon. Single object centered on a fully
transparent background, the hexagon's bottom edge near the bottom of the canvas, nothing else in frame,
no people, no text, no neon.
```

Негатив: `isometric diamond, 45 degree rotation, dimetric, rhombus base, oval base, square base, side view, photo, 3D render, pixel art, second building, cropped object, white background, text, long shadow outside the base`.

Уровни — как раньше: t1, затем t2/t3 правкой t1 («same building, same camera and hexagonal base, upgraded: …»). Описания самих зданий брать из `ART_TASK_CODEX.md` §2 (P1, P4) и `ART_BRIEF_v0.3.md`.

## 3. Что перерисовать (43 файла)

Имена **те же**, что сейчас используются, с суффиксом `_hex` — старые файлы не удалять до приёмки.

**Здания (33):**

| Здание | Файлы |
|---|---|
| Пост администрации | `admin_post_t1..t3_hex` |
| Главная Цистерна | `main_cistern_t1..t3_hex` |
| Склад | `warehouse_t1..t3_hex` |
| Жилой барак | `shelter_t1..t3_hex` |
| Колодец-насос | `well_pump_t1..t3_hex` |
| Пылевая грядка | `field_strip_t1..t3_hex` (сейчас `farm_t1..t3`) |
| Лесной двор | `lumber_yard_t1..t3_hex` |
| Каменный карьер | `quarry_pit_t1..t3_hex` |
| Мастерская инструментов | `tool_workshop_t1..t3_hex` |
| Солнечная панель | `solar_panel_t1_hex` |
| Генератор | `generator_t1_hex` (сейчас `power_t1`) |
| Башня Истока (старая / восстановленная) | `source_tower_old_t1_hex`, `source_tower_restored_t1_hex` |
| Контора Компании | `company_office_t1_hex` |
| Руины Компании | `company_ruin_t1_hex` |

**Реквизит (10):** все `prop_*` из `godot/assets/props/` → `prop_*_hex`, холст 512×512, то же гекс-основание (ширина ≈ 400 px, нижняя грань ≈ 30 px от низа). Трубы: `prop_pipe_straight_hex` — вдоль горизонтали гекса (от левой вершины к правой); `prop_pipe_bend_hex` — поворот на 60° к нижней-правой грани.

Формат: PNG RGBA, прозрачный фон, без обрезков по краям. Высокие объекты (башня) могут уходить вверх на всю высоту холста.

## 4. Подключение (код)

1. `godot/content/base/buildings.json`: у каждого перерисованного здания заменить пути в `sprites_by_level` на `_hex`-файлы и добавить `"footprint": "hex"`.
2. `godot/scripts/scenes/building_layer.gd` → `_draw_building_sprite`: сейчас якорь считается для ромба: `anchor = Vector2(width * 0.5, draw_size.y - width * 0.25)`. Для `footprint == "hex"`:
   - ширина спрайта = ширина гекса × запас юбки: `width = HexCoords.HEX_SIZE * 2.0 * 1.04`;
   - полувысота гекса в долях ширины = `0.75 * sin(60°) / 2 ≈ 0.325` → `anchor = Vector2(width * 0.5, draw_size.y - width * 0.325)`;
   - тень-подложку (`draw_colored_polygon` тёмным гексом) для hex-спрайтов **не рисовать** — юбка уже гекс.
   Ромбовую ветку оставить для спрайтов без флага (fallback).
3. `godot/scripts/scenes/hex_terrain_layer.gd` → `_draw_props`: для `_hex`-пропсов тот же якорь (`width = HEX_SIZE * 2.0 * 0.9`, `anchor.y = draw_size.y - width * 0.325`). Выбор файла: если есть `<id>_hex.png` — брать его.
4. Обрезка по силуэту (`_main_silhouette_rect`) остаётся — она не зависит от проекции.

## 5. Проверки и приёмка

Как в `ART_TASK_CODEX.md` §4 (прогреть импорт, boot scan, `balance_sim`, `save_roundtrip`, скриншот). Логика не меняется — исходы A–F должны совпасть.

Приёмка:
- [ ] на `map.png` нижняя кромка каждого здания совпадает с нижней гранью его клетки, юбка не выходит за гекс (проверить кропом 3× вокруг 5 разных зданий);
- [ ] стены зданий вертикальны и параллельны экрану, ни одного ромба в основании;
- [ ] соседние здания на соседних клетках не перекрывают друг друга юбками;
- [ ] при выделении клетки (контур гекса, уже в `main`) контур совпадает с юбкой здания;
- [ ] контактный лист: каждый спрайт рядом с гекс-тайлом того же масштаба — `docs/images/visual_pass_b_p7_sheet.png`;
- [ ] в уменьшении до 64 px силуэты по-прежнему различимы (насос ≠ цистерна ≠ башня);
- [ ] `balance_sim` A–F и `save_roundtrip` без изменений.

Сначала сделать **три пробных** (`shelter_t1_hex`, `well_pump_t1_hex`, `source_tower_old_t1_hex`), подключить, снять скриншот и приложить к черновому PR — проекцию утверждаем на них, потом остальные 40.
