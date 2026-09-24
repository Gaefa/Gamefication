# Задание P5: пины и иконки над зданиями (внутриигровой UI)

Продолжение `docs/ART_TASK_CODEX.md` (P1–P4 влиты). Стартовать от свежего `main`. Ветка `cod/visual-b5-pins`, один PR со скриншотами до/после.

## 0. Зачем

Пины — главный канал диагностики (UX_BIBLE §5, §6): здание сообщает игроку **одну главную причину** проблемы. Сейчас это цветной кружок с буквой (`R`, `E`, `W`, `P`, `!`) — читается только с легендой. Нужны иконки, которые понятны без буквы, в одном визуальном языке, но **не в живописном стиле зданий**: пины — это UI поверх мира, они должны быть плоскими, контрастными и читаться при ширине 20 px.

Код, который их рисует: `godot/scripts/scenes/overlay_layer.gd` → `_primary_diagnostic()` выбирает одну причину, `_draw_diagnostic_pin()` рисует кружок с буквой над зданием (смещение `(14, -28)` от центра клетки, радиус 9 px).

## 1. Стиль пинов

- **Форма:** круглый бейдж с тонким тёмным контуром (2 px при 128 px) и коротким «хвостиком» вниз, как у карты. Внутри — белая пиктограмма. Заливка бейджа = семантический цвет.
- **Пиктограмма:** одноцветная (белая), плоская, без градиентов и теней, толстые линии (не тоньше 10 px при холсте 128), занимает ~65 % диаметра. Никакого текста и букв.
- **Цвета:** красный `#e63535` — здание остановилось (error, мигает); жёлтый `#e6a02b` — предупреждение (warning); синий `#2f7fe6` — вода; голубой `#7fb8ff` — напор (warning по воде).
- **Референс стиля:** пиктограммы уровня иконок карт (Google Maps / Apple Maps POI-бейджи): читаемость важнее детализации. Ни в коем случае не рисованная изометрия зданий.
- **Читаемость:** проверять, уменьшив до 20×20 px, — форма должна отличаться от соседних пинов силуэтом, а не только цветом (дальтоники).

## 2. Технические требования

| Параметр | Значение |
|---|---|
| Формат | PNG RGBA, прозрачный фон |
| Холст | 128×128, бейдж вписан по ширине, хвостик касается нижнего края |
| Имя | `pin_<label>.png` в `godot/assets/ui/pins/`, где `<label>` = поле `label` из `_primary_diagnostic()` |
| Доп. | тот же набор как SVG в `godot/assets/ui/pins/src/` — на будущее для масштабирования |

## 3. Список пинов (7 обязательных + 1 задел)

`label` — ключ, по которому код найдёт файл. Семантика — из `_primary_diagnostic()` и UX_BIBLE §5.

| Файл | label | Когда | Цвет | Пиктограмма |
|---|---|---|---|---|
| `pin_repair` | `repair` | здание повреждено, нужен ремонт (R) | красный, мигает | **сломанная шестерёнка** — шестерёнка с выломанным зубом / трещиной |
| `pin_issue` | `issue` | у здания проблема, генерирует риск | жёлтый | **восклицательный знак** |
| `pin_road` | `road` | нет дороги рядом — здание вне логистики | красный | **ящик с крестом** (канон) — контур ящика и × поверх |
| `pin_power` | `power` | нет электричества (сброшено директором энергии) | жёлтый | **молния, перечёркнутая** одной диагональю |
| `pin_water` | `water` | дом вне покрытия воды | красный | **перечёркнутая капля** (канон) |
| `pin_stock` | `stock` | запас воды в цистерне = 0 | синий | **пустая капля** — только контур капли, внутри пусто |
| `pin_pressure` | `pressure` | слабый напор (< 0.8): дом далеко от насоса или насос перегружен | голубой | **капля со стрелкой вниз** внутри |
| `pin_event` | `event` | задел: над зданием есть нарративное событие (кликнуть) | белый бейдж, тёмный знак | **говорящий пузырь** с точкой. Код пока не использует — просто положить файл |

Уровень здания (точки под ним) и красный крест на повреждённом спрайте остаются как есть — пин их дополняет.

## 4. Промпты

База (для всех пинов):

```
Flat game UI map pin icon. A round badge with a thin dark outline and a short pointer tail at the bottom,
solid <COLOR> fill, a single white pictogram inside taking about two thirds of the badge.
Bold simple shapes, thick strokes, no text, no letters, no gradients, no shadows, no 3D, no photo.
Centered on a fully transparent background, nothing else in frame. Must stay readable when scaled to 20 pixels.
```

Негатив: `text, letters, numbers, gradient, glossy, 3D, bevel, drop shadow, painterly, isometric building, background, multiple icons, watermark`.

Пер-пин (`<COLOR>` подставить):

| Файл | `<COLOR>` | Строка |
|---|---|---|
| `pin_repair` | red #e63535 | `pictogram: a gear with one tooth broken off and a crack through it` |
| `pin_issue` | amber #e6a02b | `pictogram: a bold exclamation mark` |
| `pin_road` | red #e63535 | `pictogram: a simple crate outline with a large X across it` |
| `pin_power` | amber #e6a02b | `pictogram: a lightning bolt crossed out by one diagonal bar` |
| `pin_water` | red #e63535 | `pictogram: a water drop crossed out by one diagonal bar` |
| `pin_stock` | blue #2f7fe6 | `pictogram: a water drop drawn as an outline only, hollow inside` |
| `pin_pressure` | light blue #7fb8ff | `pictogram: a water drop with a small downward arrow inside it` |
| `pin_event` | white #f4f1ea, dark pictogram #2b2622 | `pictogram: a speech bubble with a single dot inside` |

Генерировать все 8 одним сеансом с одним и тем же базовым промптом, первый принятый пин прикладывать референсом к остальным — так бейдж, контур и хвостик совпадут.

## 5. Подключение (код)

В `godot/scripts/scenes/overlay_layer.gd`:

1. `_draw_diagnostic_pin(coord, diag)`: по `diag.label` взять текстуру `res://assets/ui/pins/pin_<label>.png` (кэш в словаре, как `_prop_cache` в `hex_terrain_layer.gd`; отсутствующий файл запомнить как `null`). Если текстура есть — `draw_texture_rect(tex, Rect2(center - Vector2(11, 11), Vector2(22, 22)), false, tint)`, где `center` — прежнее смещение `(14, -28)`, а хвостик должен указывать на здание (сдвинуть так, чтобы низ бейджа был у `center + (0, 11)`). Если текстуры нет — прежний кружок с буквой (fallback обязателен).
2. Мигание красных пинов (`repair`, `road`, `water`): `tint.a = 0.55 + 0.45 * abs(sin(Time.get_ticks_msec() / 400.0))`. Чтобы мигало, слой должен перерисовываться каждый кадр, пока есть хоть один такой пин: в `_process` → `queue_redraw()` только если `_has_blinking_pin` (флаг выставляется при последней отрисовке). Без пинов — не перерисовывать каждый кадр.
3. В `godot/scripts/scenes/building_layer.gd` убрать вызов `_draw_alert` для зданий со спрайтом (жёлтый `!` над спрайтом дублирует пин `issue`); `_draw_crack` оставить.
4. Тултип по наведению не нужен — клик по зданию и так показывает причину в инфо-панели.

## 6. Проверки

Как в `ART_TASK_CODEX.md` §4 (прогреть импорт, boot scan, `balance_sim`, `save_roundtrip`) — логика не меняется, исходы должны совпасть. Плюс:

- `tools/screenshot.tscn` → на `map.png` в стартовом городе виден хотя бы один пин (у поста администрации сейчас стоит `R`) — приложить крупный кроп 200×200 вокруг пина.
- Скриншот с искусственно сломанным зданием (в `tools/` можно сделать `pins_smoke.gd`: выставить `damaged=true`, `powered=false`, убрать покрытие, вызвать redraw, снять кадр) — чтобы все 7 пинов были видны на одном кадре.
- Уменьшенный до 20 px ряд всех пинов — в контактном листе `docs/images/visual_pass_b_p5_pins.png`.

## 7. Не входит (следующий этап, P6, по отдельному заданию)

Иконки ресурсов в верхней панели, иконки шкал давления, значки категорий меню строительства, курсоры режимов. Не трогать.
