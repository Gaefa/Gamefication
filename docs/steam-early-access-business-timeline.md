# Steam Early Access Business Timeline

Актуально на: 2026-04-26.

Цель документа: зафиксировать реалистичный календарь выхода в Steam, когда покупать Steam Direct, когда открывать страницу, когда делать demo/playtest, когда можно выходить в Early Access и какие траты планировать.

## 1. Короткий Вывод

Рекомендация: не идти в публичный Steam Early Access сразу после v0.2. v0.2 должна быть закрытым playtest build. Публичный EA стоит планировать только после v0.3/v0.4, когда есть стабильный сценарий, понятный UI, нормальный export и минимум 30-45 минут честной игры.

Реалистичные даты от текущего состояния:

- `2026-04-27 -> 2026-05-24`: v0.2 closed playtest candidate.
- `2026-05-01 -> 2026-05-07`: купить Steam Direct / пройти Steamworks onboarding.
- `2026-05-25 -> 2026-06-07`: закрытый playtest 5-10 человек, фиксы, сбор фидбека.
- `2026-06-08 -> 2026-06-21`: v0.3 store/demo prep, скриншоты, capsule, trailer draft.
- `2026-06-15 -> 2026-06-21`: отправить Steam store page на review.
- `2026-06-22`: целевая дата открытия Steam Coming Soon page.
- `2026-07-06`: минимально возможная дата релиза после 2 недель Coming Soon, но это слишком рано.
- `2026-08-17`: earliest credible Steam Early Access, если v0.3/v0.4 проходят QA.
- `2026-09-14 -> 2026-10-12`: recommended Steam Early Access window.

Практический ответ: Steam Direct покупать в первую неделю мая 2026. Coming Soon открывать в конце июня 2026. Early Access целиться на сентябрь 2026, не раньше августа.

## 2. Почему Не Раньше

Steam Early Access не должен быть способом собрать деньги на доделку. Steam прямо позиционирует EA как продажу уже playable alpha/beta, которая стоит своей текущей цены и будет дальше развиваться.

Для нашей игры это значит:

- должна быть победа/поражение хотя бы в одном сценарии;
- игрок должен понимать причины дефицита;
- save/load не должен ломать обычную игру;
- UI не должен выглядеть как debug overlay;
- игра должна быть ценна уже сейчас, а не "когда-нибудь после 10 патчей".

## 3. Steam Requirements, Которые Влияют На Сроки

Официальные ограничения Steam:

- Steam Direct fee: `$100 USD` за продукт.
- Fee не refundable, но recoupable после `$1,000 Adjusted Gross Revenue`.
- После оплаты fee для первых продуктов действует `30-day waiting period` до возможности релиза.
- Store page и build проходят review.
- Store presence review обычно занимает `3-5 business days`; планировать надо минимум `7 business days`.
- Product build review тоже обычно `3-5 business days`; планировать минимум `7 business days`.
- Coming Soon page должна быть публичной минимум `2 weeks` до релиза.
- За 14 дней до release date менять дату становится сложнее/невозможно без обращения к Steam.

Источники:

- Steam Direct / onboarding: https://partner.steamgames.com/steamdirect/
- Steam Direct fee: https://partner.steamgames.com/doc/gettingstarted/appfee
- Steam review process: https://partner.steamgames.com/doc/store/review_process
- Release options / Coming Soon: https://partner.steamgames.com/doc/store/types
- Release dates: https://partner.steamgames.com/doc/store/release_dates
- Early Access: https://partner.steamgames.com/doc/store/earlyaccess

## 4. Что Покупать И Когда

### Неделя 1: 2026-05-01 -> 2026-05-07

Купить/сделать:

- Steam Direct app credit: `$100`.
- Steamworks onboarding: legal identity, bank info, tax info.
- Подготовить рабочее название, developer name, publisher name.

Почему сейчас:

- запускаем 30-дневный Steam waiting period;
- получаем appID;
- можем заранее видеть checklist Steamworks;
- цена низкая относительно риска задержать релиз на месяц.

Не покупать пока:

- дорогой trailer;
- дорогой key art;
- платный PR;
- локализацию на 10 языков;
- музыку/саунд-пак "на потом".

### Неделя 5-6: 2026-05-25 -> 2026-06-07

Покупать только если v0.2 playtest не провалился:

- capsule/key art polish, если свой арт не вытягивает: ориентир `$100-$500`;
- trailer editing, если сами не собираем: ориентир `$300-$1,500`;
- домен/лендинг опционально: `$10-$30/year`;
- Discord/community setup: `$0`.

### Неделя 7-8: 2026-06-08 -> 2026-06-21

Готовить Steam page:

- short description;
- long description;
- 5-8 gameplay screenshots only;
- 1 short trailer или animated capture;
- capsule images;
- tags;
- supported languages: English, Russian;
- Early Access Q&A;
- pricing draft.

Рекомендация по цене EA:

- если v0.3/v0.4 дает 45-60 минут хорошего replayable loop: `$9.99-$14.99`;
- если контента мало и это честный alpha: `$7.99-$9.99`;
- не ставить ниже `$7.99`, если хотим восприниматься как premium citybuilder, а не disposable prototype.

## 5. Calendar Plan

### Phase 0: Сейчас -> v0.2

Dates: `2026-04-27 -> 2026-05-24`.

Goal: closed playtest candidate.

Deliverables:

- road logistics distance v1;
- utility model v1;
- first scenario;
- citizen demands;
- safe map generation;
- events/pressure pass;
- level 1-4 balance;
- build checklist.

Exit gate:

- 30-minute playthrough without blocker;
- scenario can win/loss;
- player can understand shortages via UI;
- Godot headless passes;
- Windows export exists.

### Phase 1: Steamworks Setup

Dates: `2026-05-01 -> 2026-05-07`.

Goal: remove platform blockers.

Actions:

- pay Steam Direct fee;
- complete paperwork;
- get appID;
- create private app shell;
- do not publish Coming Soon yet.

Exit gate:

- Steamworks app exists;
- release checklist visible;
- 30-day timer is running.

### Phase 2: Closed Playtest

Dates: `2026-05-25 -> 2026-06-07`.

Goal: verify whether v0.2 is understandable by strangers.

Test group:

- 5-10 people;
- 3 players who know citybuilders;
- 3 players who do not know this project;
- 1-2 technical testers.

Required questions:

- What is your current objective?
- Why is your worst building inefficient?
- What resource blocks progress?
- What would you build next?
- Did the UI lie or confuse you?
- Would you play another run?

Exit gate:

- at least 70% understand next objective;
- at least 70% understand why they failed/succeeded;
- no save/load blocker;
- at least 3 testers play 20+ minutes without live explanation.

### Phase 3: v0.3 Store/Demo Prep

Dates: `2026-06-08 -> 2026-06-21`.

Goal: Steam Coming Soon page candidate.

Deliverables:

- v0.3 build;
- store screenshots from real gameplay;
- trailer draft;
- capsule draft;
- English/Russian store text;
- Early Access Q&A;
- pricing draft;
- known issues list.

Steam action:

- submit store page for review around `2026-06-15`.
- target Coming Soon live around `2026-06-22`.

Exit gate:

- Steam page review approved;
- screenshots match current build;
- description does not promise missing systems as shipped features.

### Phase 4: Wishlist / Demo / Playtest Window

Dates: `2026-06-22 -> 2026-08-16`.

Goal: build audience and validate conversion before paid EA.

Actions:

- Coming Soon page live;
- collect wishlists;
- run Steam Playtest or external key playtest;
- publish devlog/updates every 1-2 weeks;
- fix top playtest issues;
- decide whether to make public demo.

Targets:

- 500 wishlists: minimum signal, EA possible but weak.
- 1,000 wishlists: acceptable small indie EA.
- 3,000+ wishlists: better launch odds.

If under 500 wishlists by mid-August:

- do not launch paid EA;
- improve store page/trailer;
- release demo;
- continue playtests.

### Phase 5: Early Access Candidate

Earliest credible: `2026-08-17`.

Recommended: `2026-09-14 -> 2026-10-12`.

EA content minimum:

- 1 polished scenario;
- sandbox basic mode;
- city levels 1-5;
- 15-18 buildings;
- tech/policy visible and useful;
- 10+ events/crises;
- save/load stable;
- RU/EN;
- Windows build;
- clear 3-month update roadmap.

Launch gates:

- store page approved;
- build approved;
- Coming Soon >= 2 weeks;
- 30-day waiting period finished;
- no blocker bugs;
- at least 5 external testers complete one run or fail clearly;
- launch discount configured if used.

## 6. Budget

Required minimum:

- Steam Direct: `$100`.
- Godot: `$0`.
- Steam page: `$0`.
- Windows export: `$0`.

Recommended lean budget:

- Steam Direct: `$100`.
- Capsule/key art cleanup: `$100-$500`.
- Trailer edit: `$0-$1,500`.
- Sound/music placeholder polish: `$0-$300`.
- Domain/landing page: `$10-$30/year`.
- Contingency: `$300-$1,000`.

Total realistic lean budget:

- DIY-heavy: `$110-$300`.
- Safer presentation: `$600-$2,500`.

Do not spend paid marketing before:

- Coming Soon page is live;
- trailer/store page converts decently;
- v0.2/v0.3 playtest feedback says people understand the game.

## 7. What To Buy Checklist

Buy now / May 2026:

- [ ] Steam Direct app credit.
- [ ] Optional domain.

Buy after v0.2 playtest passes:

- [ ] Capsule/key art polish.
- [ ] Trailer help if needed.
- [ ] Audio polish if current audio hurts perception.

Buy only near EA:

- [ ] PR outreach tools/services.
- [ ] Additional localization.
- [ ] Paid trailer/key art upgrade.

Do not buy for v0.2:

- [ ] Mobile store fees.
- [ ] Console dev programs.
- [ ] DLC art.
- [ ] Large music pack.
- [ ] Paid ads.

## 8. Steam Page Content Plan

Positioning:

> A compact post-collapse citybuilder where roads deliver physical resources, underground utilities keep districts alive, and a pressure director turns growth into crises.

Core tags:

- City Builder;
- Colony Sim;
- Management;
- Strategy;
- Simulation;
- Base Building;
- Resource Management;
- Survival;
- Singleplayer.

Screenshots needed:

- city overview with roads/buildings;
- selected building diagnostics;
- utility coverage overlay;
- crisis/event popup;
- tech/policy panel;
- city level/objective panel;
- upgraded district with sprites;
- map generation/terrain.

Trailer structure:

- 0-5s: hook, city growing under pressure;
- 5-15s: build roads/resources/housing;
- 15-25s: logistics + utility coverage;
- 25-35s: crises and decisions;
- 35-45s: upgrades/progression/scenario objective;
- 45-55s: title + Coming Soon / Early Access.

## 9. Full Release Outlook

If EA starts around September 2026:

- v0.5: November 2026, more scenarios/events/QoL.
- v0.6: January 2027, deeper policies/tech and balance.
- v0.7: March 2027, scenario pack + endgame pressure.
- v0.8: May 2027, Steam Deck polish and performance.
- v0.9: July 2027, content lock candidate.
- 1.0: August-October 2027 if retention/reviews are healthy.

If EA feedback is weak:

- do not push 1.0;
- use EA for redesign of onboarding, UI clarity, and core loop;
- delay 1.0 until players voluntarily replay.

## 10. Decision Gates

### Gate A: Buy Steam Direct

Date: `2026-05-01 -> 2026-05-07`.

Decision: buy.

Reason: low cost, starts 30-day clock, removes platform uncertainty.

### Gate B: Publish Coming Soon

Date: around `2026-06-22`.

Decision: publish only if screenshots are from real gameplay and v0.2 feedback is not catastrophic.

### Gate C: Paid EA

Date: `2026-08-17` earliest, recommended `2026-09-14 -> 2026-10-12`.

Decision: launch only if player comprehension and stability gates pass.

### Gate D: Full 1.0

Date: Q3 2027 target.

Decision: only after content depth, review stability, and retention are acceptable.
