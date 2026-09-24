# Mandate Cities

Градостроитель о **власти взаймы**. Вы — администратор, назначенный Лигой Восстановления в Ржавую Нору, сухой район после Разлома. Удержать воду, удержать людей, пережить сезон Пыли и аудит на 20-й день — при том, что хозяев двое, Лига и город, и угодить обоим нельзя.

Одна партия — 20–40 минут. Движок Godot 4.6.

- **Гид для игрока и тестера:** [docs/PLAYER_GUIDE.md](docs/PLAYER_GUIDE.md) — что за игра, цель, управление, панели, вопросы для обратной связи.
- **Дизайн-канон:** `docs/GAME_DESIGN_BIBLE.md`, `docs/GDD.md`, `docs/CONTENT_BIBLE.md`, `docs/UX_BIBLE.md`, `docs/LORE_BIBLE.md`, `docs/RELEASE_PLAN.md`.
- **Графика:** `docs/ART_BRIEF_v0.3.md` (стиль и ТЗ), `docs/ART_TASK_CODEX.md` (пошаговое задание на генерацию).

## Скачать сборку

Каждый push в `main` собирает Windows EXE и macOS DMG в GitHub Actions («Godot Export» → Artifacts). macOS: при первом запуске — правый клик → «Открыть», сборка не подписана.

## Запуск из исходников

```bash
git clone https://github.com/Gaefa/Gamefication.git
cd Gamefication/godot
Godot --path . --editor   # один раз, чтобы прогреть импорт
Godot --path .
```

Godot 4.6.1 или новее. Первый headless-запуск без прогретого импорта выдаёт ложные `Parse Error` — это отсутствующий кэш классов, а не ошибка кода.

## Проверки для разработчика

```bash
Godot --headless --path godot res://tools/balance_sim.tscn        # экономика, сценарии A–F
Godot --headless --path godot res://tools/save_roundtrip.tscn     # сохранение тик-в-тик
Godot --headless --fixed-fps 60 --path godot res://tools/loop_smoke.tscn   # полный цикл до финала
Godot --path godot --resolution 1280x720 res://tools/screenshot.tscn -- out=/abs/dir   # menu.png, map.png
```

## Структура

- `godot/` — игра. `scripts/autoload` — сервисы (состояние, события, мандат, соперник, финалы), `scripts/core` — симуляция (сезоны, вода, давление, экономика), `scripts/scenes` — карта и HUD, `content/base` — весь контент в JSON, `tools/` — headless-проверки.
- `docs/` — канон и задания.
- `src/`, `game.js`, `index.html` — старый браузерный прототип (Pixel City Builder). Не развивается; оставлен как справка.
