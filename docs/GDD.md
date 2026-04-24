# Game Design Document

## 1. High Concept

Рабочее название: `Pixel City Builder`.

Жанр: premium single-player citybuilder / colony management / crisis survival.

Формула: `Cities: Skylines scale fantasy` + `RimWorld pressure director` + `Rebel Inc-style governance tradeoffs` в компактной, процедурной, replayable форме.

Игрок строит город, управляет ресурсами, сервисами, технологиями, политиками и гражданскими требованиями. Город не просто растет: он начинает предъявлять требования, ломаться под нагрузкой и реагировать на решения игрока.

## 2. Design Pillars

1. `Cause And Effect`
- игрок всегда должен понимать, почему ресурс не доходит, почему дом недоволен, почему кризис усилился.

2. `Readable Complexity`
- системы глубокие, но UI объясняет результат через diagnostics, overlays и clear warnings.

3. `Pressure, Not Punishment`
- кризисы создают решения, а не просто случайно ломают город.

4. `District Identity`
- районы должны отличаться: промышленный кластер, жилой квартал, культурный центр, транспортный узел.

5. `Base Game Must Be Complete`
- технологии и политики входят в базовую игру.
- DLC расширяют контент, инфраструктуру и сценарии, но не продают фундаментальные системы.

## 3. Target Platforms

Primary:
- Steam Windows.

Secondary:
- Steam Deck after controls pass;
- iPadOS;
- Android tablets;
- iPhone/Android phones only after mobile UI pass.

## 4. Core Loop

1. Выбрать стартовый район на процедурной карте.
2. Построить дороги, жилье и добычу.
3. Обеспечить food, coins, logistics, water coverage, power coverage.
4. Реагировать на shortages, issues, damage, crisis events.
5. Исследовать технологии и выбирать политики.
6. Развивать районы через adjacency bonuses и service coverage.
7. Достичь сценарной цели или уйти в endless/endgame pressure.

## 5. Game Modes

### Scenario Mode

Основной режим для релиза.

Примеры:
- `Found A Stable Town`;
- `Water Under Pressure`;
- `Industrial Boom`;
- `After The Quake`;
- `Metropolis Mandate`.

### Sandbox

Свободная игра с настройками карты, сложности и pressure profile.

### Endless / Prestige

Endgame-режим после победы в сценарии:
- rising pressure;
- stricter citizen demands;
- prestige stars;
- legacy bonuses for future runs.

## 6. Resources And Utilities

### Stockpile Resources

Копятся в городе:
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
- fame;
- water reserve.

### Utilities

Не являются складом, работают локально:
- road access;
- water coverage;
- power coverage.

Правило: stockpile отвечает на вопрос `сколько у города есть`, utility отвечает на вопрос `покрыта ли конкретная клетка`.

## 7. Buildings

Базовые категории:
- Residential;
- Production;
- Commercial;
- Culture;
- Infrastructure;
- Advanced.

Обязательные building roles:
- housing;
- food production;
- raw material extraction;
- processing chains;
- trade/income;
- happiness/culture;
- water service;
- power service;
- logistics/storage;
- science/endgame.

## 8. Adjacency And Districts

Соседство должно быть стратегическим.

Positive:
- market near residential increases income;
- park near residential increases happiness;
- library near research increases science;
- warehouse near production improves logistics;
- upgraded road near production improves output.

Negative:
- dirty production near residential reduces happiness;
- dense housing without services increases pressure;
- repeated same building cluster increases fragility.

## 9. Technologies

Технологии входят в базовую игру.

Функции:
- unlock buildings;
- improve production efficiency;
- reduce disaster damage;
- improve utility coverage;
- unlock policy categories;
- unlock scenario solutions.

Техническое правило: technology effects are modifiers, not hardcoded if-statements inside buildings.

## 10. Policies

Политики входят в базовую игру.

Policy categories:
- taxation;
- labor;
- environment;
- security;
- welfare;
- urban planning;
- emergency response.

Policy design:
- each policy has benefit, cost, pressure impact, citizen demand impact;
- policies should create tradeoffs, not obvious upgrades;
- switching policies can have cooldown or transition cost.

## 11. Citizen Demands

Citizen demands scale with city level.

Early:
- food security;
- road access;
- water coverage.

Mid:
- power coverage;
- safety;
- healthcare-like crisis response;
- leisure.

Late:
- education/science;
- culture;
- pollution control;
- ideological/political expectations;
- resilience standards.

## 12. Pressure Director

Inputs:
- city size;
- deficits;
- low happiness;
- damaged buildings;
- unmet demands;
- policy instability.

Outputs:
- event weights;
- crisis intensity;
- issue frequency;
- disaster eligibility.

Goal: create escalating drama without hidden cheating.

## 13. MVP Scope

Must have:
- procedural playable map;
- resource flow;
- water/power/road coverage;
- building diagnostics;
- 12-15 buildings;
- 6-8 core resources;
- 5 city levels;
- tech tree v1;
- policy deck v1;
- 8-10 events;
- 1 scenario;
- save/load;
- Windows export.

Must not have:
- mobile UI;
- paid DLC;
- complex religion/ideology;
- full metro/rail systems;
- multiplayer.

## 14. Vertical Slice Scope

Add:
- 15-18 buildings;
- 10-12 events;
- citizen demands v1;
- adjacency penalties;
- first complete scenario;
- tutorial;
- settings;
- export pipeline;
- playtest feedback loop.

## 15. Success Criteria

Internal MVP:
- 20 minute play session without explaining mechanics verbally.

Vertical slice:
- 5 external testers complete or fail scenario and can explain why.

Steam demo:
- 45-60 minute session;
- wishlists/feedback validate core loop;
- no major trust-breaking economy bugs.
