# Gameplay Roadmap To A Concrete Game

Цель: сделать не набор систем, а понятный citybuilder, где игрок строит город, видит причины проблем, принимает решения под давлением и доходит до endgame-сценария.

## 0. Текущий Фокус

Сейчас нельзя масштабировать контент, пока базовые причинно-следственные связи не ясны.

Приоритет:
1. Ресурсы и доставка.
2. UI-диагностика зданий и города.
3. Генерация карты и влияние соседних клеток.
4. Кризисы и pressure director.
5. Сценарии, tech/policy и endgame.

## 1. Core Loop

Базовый цикл игрока:
1. Разведать карту и выбрать место под район.
2. Построить дороги, жилье и первичную добычу.
3. Обеспечить доставку ресурсов, воду, энергию и сервисы.
4. Реагировать на дефициты, аварии и кризисы.
5. Улучшать здания и специализировать районы.
6. Пройти сценарную цель или выйти в endless/endgame pressure.

Критерий: игрок всегда должен понимать, почему город растет или ломается.

## 2. Ресурсы И Utilities

### Складовые Ресурсы

Это глобальные или доставляемые ресурсы, которые копятся в запасах:
- coins;
- food;
- wood;
- stone;
- planks;
- bricks;
- tools;
- cloth;
- metal;
- glass;
- science;
- culture;
- fame.

### Utilities

Это не обычный склад, а локальное покрытие/мощность:
- road access;
- water coverage;
- power coverage.

Правило: UI не должен показывать utility как обычный ресурс, если механически важен радиус покрытия.

### Следующее Архитектурное Решение

Ввести отдельную модель `UtilityStatus`:
- `road_connected: bool`;
- `water_covered: bool`;
- `power_covered: bool`;
- `input_efficiency: float`;
- `output_efficiency: float`;
- `missing: Array[String]`.

## 3. Resource Flow

`ResourceFlow` должен отвечать на вопрос: может ли ресурс попасть к зданию или выйти из здания.

Правила первой версии:
- `global`: всегда доступен;
- `road`: нужен соседний road;
- `energy`: нужна power coverage для потребителей;
- `water_res`: глобальный запас Water Reserve для событий и кризисов;
- water coverage: отдельный локальный utility-статус от water tower radius;
- производители utilities сами могут производить свой utility-ресурс.

Критерий: если здание не получает входные ресурсы, оно не должно нормально производить.

## 4. UI Диагностика

На выбранном здании показывать:
- статус дороги;
- статус воды;
- статус энергии;
- эффективность производства;
- недостающие входы;
- радиусы покрытия по клавише `V`;
- понятную подсказку, что построить рядом.

Пример:

```text
Hut Lv0
Road: missing, output 30%
Water: covered
Input: Food missing by road
Efficiency: 0%
Next: build Road adjacent
```

## 5. Генерация Карты

Карта должна давать игровые решения, а не просто шум.

Нужно:
- стартовая зона без воды/скал в центре;
- кластеры леса, камня, холмов;
- реки/озера как ограничители и бонусы;
- fertile land для farm;
- adjacency rules для биомов, чтобы forest не появлялся одиночными пикселями;
- гарантированные early-game ресурсы в радиусе старта.

Критерий: первые 10 минут партии всегда играбельны, но layout отличается.

## 6. Зависимость Соседних Клеток

Соседство должно быть частью стратегии:
- farm рядом с lumber получает бонус;
- market рядом с residential усиливает налоги;
- dirty industry рядом с residential снижает happiness;
- park/library/theater дают ауры;
- road tier усиливает adjacent production;
- water/power создают service zones.

Нужен один источник правды: `SynergyResolver` + content data. Никаких hardcoded радиусов в UI.

## 7. Кризисы И Pressure

Pressure должен создавать нарастающее, но объяснимое давление.

Типы событий:
- локальные аварии: пожар, поломка, болезнь;
- экономические кризисы: спад торговли, рост maintenance;
- природные: засуха, землетрясение, метеорит;
- социальные: протест, миграция, преступность;
- opportunity events: караван, инвестор, фестиваль.

Правила:
- кризис выбирает уникальные валидные здания;
- событие объясняет место и последствия;
- игрок должен иметь 2-3 ответа с понятной ценой;
- отказ не должен быть всегда плохим, иногда это стратегический выбор.

## 8. Citizen Demands

Граждане должны требовать не абстрактное счастье, а конкретные условия:
- food security;
- water access;
- power access;
- road access;
- safety;
- leisure;
- education;
- ideology/religion compatibility в DLC.

Demand растет с уровнем города. Early game про выживание, mid game про сервисы, late game про специализацию и стабильность.

## 9. Progression

Вертикаль прогресса:
- Town Camp: базовые ресурсы;
- Village: вода, рынок, простые кризисы;
- Town: производство цепочек, культура;
- City: энергия, плотное жилье, сложные кризисы;
- Metropolis: science/fame, endgame pressure;
- Wonder City: сценарная победа или prestige.

## 10. Tech / Policy / Religion / Ideology DLC

Эти системы нельзя вшивать напрямую в здания.

Архитектурно они должны работать через modifiers:
- production modifiers;
- demand modifiers;
- event weights;
- unlock rules;
- citizen faction preferences;
- scenario objectives.

Каждый DLC добавляет content pack + systems, но не ломает base loop.

## 11. Vertical Slice

Минимальная играбельная версия:
- 12-15 зданий;
- 6-8 ресурсов;
- road/water/power coverage;
- 8-10 событий;
- 5 уровней города;
- 1 сценарная цель;
- понятный HUD и building diagnostics;
- Windows export.

Критерий готовности: тестер без объяснений играет 20 минут и понимает, почему проиграл или вырос.

## 12. Ближайшие Задачи

1. Включить `ResourceFlow` в экономику.
2. Развести `water_res` как UI/resource и water coverage как service. Done in code; next step is better utility UI.
3. Добавить building diagnostics panel.
4. Исправить уникальный выбор целей для кризисов.
5. Улучшить генерацию карты с guaranteed стартовой зоной.
6. Добавить adjacency penalties и bonuses через content data.
7. Сделать первый сценарий: `Founding A Stable Town`.
