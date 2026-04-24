# Platform Launch Roadmap: Steam, App Store, Android

Цель: довести игру от текущего Godot-прототипа до коммерческого релиза на Steam, Apple App Store и Google Play без развала архитектуры, монетизации и поддержки.

## 1. Продуктовая Позиция

Игра: premium PvE citybuilder/survival-management sandbox.

Ключевое обещание:
- строишь город на процедурной карте;
- управляешь ресурсами, сервисами, соседством и гражданскими требованиями;
- переживаешь нарастающие кризисы в стиле RimWorld/Rebel Inc;
- выходишь в сценарную победу, endless или prestige.

Нельзя позиционировать как idle/mobile city builder с таймерами. Это должен быть честный симулятор с понятными решениями.

## 2. Платформенная Стратегия

### Steam

Приоритет: primary launch platform.

Почему:
- аудитория лучше принимает premium strategy/citybuilder;
- можно выпускать demo, Early Access, Next Fest;
- проще тестировать PC-ориентированный UI;
- проще продавать DLC.

Формат:
- Windows first;
- macOS/Linux позже, если Godot export стабилен;
- Steam Deck as target after desktop controls are solid.

### Apple App Store

Приоритет: second-wave launch, не одновременно с Steam.

Почему:
- iPad может быть хорошей платформой для citybuilder;
- iPhone UI потребует отдельной адаптации;
- review/compliance строже;
- все digital unlocks должны быть через IAP.

Формат:
- сначала iPad-first build;
- iPhone только после mobile UI pass;
- premium app или free demo + full unlock через IAP.

### Android / Google Play

Приоритет: second-wave launch вместе или после iOS.

Почему:
- больше устройств и больше QA-рисков;
- premium games на Android сложнее монетизировать;
- нужно заранее проектировать performance tiers.

Формат:
- tablet-first;
- затем phones;
- free demo + full unlock вероятно лучше, чем paid upfront.

## 3. Монетизация

### Базовая Модель

Steam:
- base game: paid premium;
- launch discount 10-15%;
- demo before release;
- DLC после релиза.

Mobile:
- recommended: free download + full game unlock IAP;
- optional paid app only для iPad, если retention и reviews сильные;
- no forced ads;
- no timers;
- no pay-to-win.

### Почему Не F2P Aggressive

Эта игра про доверие, системность и долгую сессию. Если продавать ресурсы, ускорители или антикризисные кнопки, экономика станет подозрительной: игрок будет думать, что кризисы подкручены ради платежей.

Запрещено:
- продажа ресурсов;
- продажа emergency кнопок;
- ускорение строительства за деньги;
- loot boxes;
- gacha;
- платные сильные здания внутри базовой экономики.

Разрешено:
- base game unlock;
- сценарии;
- биомы;
- кризисные пакеты;
- cosmetic packs;
- music/art supporter pack;
- QoL overlays, если не превращаются в pay-to-understand.

## 4. Base Game: Tech And Policy

Технологии и политики входят в базовую игру.

Причина:
- это фундамент progression и governance;
- без них citybuilder будет казаться плоским;
- продавать базовое управление как DLC нельзя, это ломает доверие.

Base scope:
- tech tree v1;
- policy categories v1;
- modifiers for economy, pressure, citizen demands and unlocks.

## 5. DLC И Soft Push

### DLC 1: Transit Authority

Состав:
- rail tracks;
- metro lines;
- stations;
- commute demand;
- freight logistics;
- transit-oriented scenarios.

Правило: дороги и базовая логистика остаются в базе. Rail/metro расширяют масштаб и density gameplay.

### DLC 2: Leisure Districts

Состав:
- entertainment buildings;
- tourism;
- festivals;
- nightlife districts;
- stadium/theater expansions;
- happiness and public order tradeoffs.

### DLC 3: Urban Expansion Pack

Состав:
- new residential/commercial/production buildings;
- high-density variants;
- new city services;
- megaprojects;
- new adjacency patterns.

### DLC 4: Biomes And Frontiers

Состав:
- desert;
- tundra;
- islands;
- mountain valley;
- biome-specific resources and hazards.

### DLC 5: Civic Life

Состав:
- deeper citizen groups;
- education/culture chains;
- public institutions;
- city identity scenarios.

### Supporter Pack

Состав:
- soundtrack;
- artbook;
- cosmetic skins;
- founder monument.

## 5. MVP До Vertical Slice

### MVP Internal

Цель: доказать, что игра работает как citybuilder.

Обязательные системы:
- карта с безопасным стартом;
- строительство и bulldoze;
- road/water/power coverage;
- складовые ресурсы;
- ResourceFlow;
- building diagnostics;
- 10-12 зданий;
- 6-8 ресурсов;
- 5-8 событий;
- save/load;
- Windows export.

Критерий: разработчик может сыграть 20 минут без консольных ошибок и без объяснения самому себе, почему ресурс не работает.

### Vertical Slice

Цель: дать внешнему тестеру.

Обязательные системы:
- tutorial first 10 minutes;
- 1 сценарий `Found A Stable Town`;
- 15-18 зданий;
- city levels 1-4;
- pressure director v1;
- crisis chains v1;
- citizen demands v1;
- proper HUD;
- settings/audio/save slots;
- crash-free Windows build.

Критерий: 5 тестеров играют 30 минут; минимум 3 понимают, что делать дальше, без Discord-инструкций.

## 6. Roadmap До Steam Launch

### Phase 1: Core Clarity

Срок: 2-4 недели.

Сделать:
- закрыть все review findings;
- utility UI;
- generation v2;
- adjacency bonuses/penalties;
- first scenario skeleton;
- basic tutorial.

Exit criteria:
- no misleading resources;
- selected building explains all major problems;
- first 15 minutes playable.

### Phase 2: Playable Scenario

Срок: 4-6 недель.

Сделать:
- scenario goal and fail states;
- event chains;
- citizen demands;
- balancing pass for levels 1-4;
- content validation checks;
- save compatibility.

Exit criteria:
- можно пройти сценарий;
- кризисы ощущаются как pressure, а не random noise;
- build order не один-единственный.

### Phase 3: Steam Demo

Срок: 3-5 недель.

Сделать:
- standalone demo branch/build;
- Steam capsule/key art draft;
- trailer capture build;
- main menu;
- settings;
- feedback button/link;
- analytics-lite через локальные session stats, без invasive tracking.

Demo content:
- 1 map size;
- city levels 1-3;
- 45-60 minute cap;
- 1 scenario;
- limited endless disabled or capped.

Exit criteria:
- demo can be shipped to 20-50 testers;
- install/uninstall works;
- no save-breaking bugs in normal path.

### Phase 4: Early Access Or Full Launch Decision

Early Access подходит, если:
- core loop good;
- контента мало;
- roadmap прозрачный;
- готовы обновлять каждые 3-5 недель.

Full launch подходит, если:
- минимум 3 сценария;
- endless playable;
- meta/endgame есть;
- UX понятен без ручного обучения.

Рекомендация: Steam Early Access, если команда маленькая.

### Phase 5: Steam Launch

Launch checklist:
- store page live минимум за 2-3 месяца;
- demo раньше launch;
- wishlists campaign;
- trailer;
- screenshots;
- press kit;
- Discord/Steam community;
- bug report template;
- launch build freeze за 7 дней;
- day-1 hotfix window.

## 7. Mobile Roadmap

Mobile делать только после Steam demo feedback.

### Mobile UI Pass

Нужно:
- touch build mode;
- pinch zoom;
- larger buttons;
- bottom-sheet info panel;
- radial build menu or category drawer;
- no hover tooltips;
- readable text on 6-inch screens;
- tablet layout first.

### iOS / iPadOS

Требования:
- Apple Developer Program;
- App Store review-ready build;
- IAP for full unlock/DLC;
- privacy labels;
- age rating;
- screenshots and previews from real gameplay;
- restore purchases.

Launch format:
- iPad first;
- universal app later if iPhone UX is good.

### Android

Требования:
- Play Console account;
- target current required API level;
- internal testing track;
- closed testing;
- device tier QA;
- privacy/data safety forms;
- billing integration for full unlock/DLC.

Launch format:
- open beta or staged rollout;
- tablet-first marketing;
- avoid ad-driven monetization.

## 8. Update Plan

### Before Launch

Cadence:
- internal builds weekly;
- tester builds every 2 weeks;
- public demo updates every 4-6 weeks.

Update types:
- clarity updates;
- balance updates;
- crisis/event updates;
- map generation updates.

### After Steam Launch

First 30 days:
- hotfixes as needed;
- no major balance rewrites in first 72 hours unless game-breaking;
- weekly known issues post.

First 3 months:
- update 1: QoL + UI clarity;
- update 2: new crisis/event pack free;
- update 3: first new scenario free.

First paid DLC:
- only after base game reviews stabilize;
- target 2-4 months after launch;
- must add scenario/mechanics, not just numbers.

## 9. Pricing Draft

Steam:
- base game: 14.99-24.99 USD depending on content depth;
- Early Access: 14.99-19.99 USD;
- launch discount: 10-15%;
- DLC: 4.99-9.99 USD;
- supporter pack: 4.99 USD.

Mobile:
- free demo + full unlock: 4.99-9.99 USD;
- scenario DLC: 1.99-4.99 USD;
- cosmetics/supporter: 0.99-2.99 USD.

Decision rule:
- if game is deep and session length is PC-like, do not race to cheap mobile pricing.
- if mobile retention is weak, do not compensate with aggressive monetization; fix UI and session design.

## 10. Store Assets

Steam:
- capsule art;
- short description;
- long description;
- 6-8 screenshots;
- 1 gameplay trailer;
- tags: City Builder, Strategy, Simulation, Colony Sim, Management, Singleplayer.

App Store / Google Play:
- app icon;
- screenshots for phone/tablet;
- preview video;
- short description;
- privacy labels/data safety;
- age rating;
- IAP descriptions.

## 11. Technical Release Checklist

Build:
- deterministic version number;
- changelog;
- export presets per platform;
- signing pipeline;
- crash logs;
- save migration;
- content validation.

QA:
- first 30 minutes test;
- save/load after 30 minutes;
- low resource crisis test;
- invalid purchase restore test on mobile;
- offline launch;
- window resize;
- ultrawide;
- low-end Android device.

Godot:
- lock engine version per release branch;
- no editor-only files in build;
- export templates pinned;
- platform-specific input maps.

## 12. Risk Register

High risks:
- mobile UI too dense;
- simulation performance on low-end devices;
- monetization perceived as selling solutions to artificial crises;
- save migration breaks after content changes;
- store review delays.

Mitigation:
- PC first;
- mobile after UI rewrite;
- no paid power;
- content IDs immutable;
- release checklist per store.

## 13. Immediate Next Steps

1. Add utility UI polish: separate top-bar `Water Reserve` from local `Water Coverage`.
2. Implement adjacency penalties and bonuses.
3. Create first scenario `Found A Stable Town`.
4. Add content validation script.
5. Prepare Windows demo export folder and build naming.
6. Create Steam store asset checklist.

## 14. Official References

- Steam Direct Product Submission Fee: https://store.steampowered.com/sub/163632/Documentation
- Apple Developer Program enrollment: https://developer.apple.com/programs/enroll/
- Apple App Review Guidelines: https://developer.apple.com/appstore/resources/approval/guidelines.html
- Google Play Console setup: https://support.google.com/googleplay/android-developer/answer/9859062
- Google Play target API requirements: https://developer.android.com/google/play/requirements/target-sdk
- Google Play service fees: https://support.google.com/googleplay/android-developer/answer/11131145
