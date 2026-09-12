# Release Plan

## 1. Release Strategy

Primary path:
1. Internal MVP.
2. Closed playtest build.
3. Steam demo.
4. Steam Early Access or full launch decision.
5. Steam launch.
6. Mobile tablet-first adaptation.
7. App Store / Google Play launch.

Recommendation: Steam first. Mobile after proof that the game is readable and fun on PC.

## 2. Milestone 0: Foundation

Goal: remove trust-breaking systems.

Deliverables:
- resource flow works;
- water reserve separated from water coverage;
- building diagnostics;
- playable map generation;
- save validation;
- crisis targeting is deterministic and fair.

Exit criteria:
- no known misleading resource UI;
- Godot headless runtime check passes;
- 20 minute internal playthrough.

## 3. Milestone 1: Internal MVP

Goal: one playable city loop.

Deliverables:
- tech tree v1;
- policy system v1;
- citizen demands v1;
- adjacency bonuses/penalties;
- first scenario skeleton;
- tutorial steps v1;
- balance pass for first 30 minutes.

Exit criteria:
- scenario can be won or lost;
- diagnostics explain failure states;
- no blocker bugs in save/load.

## 4. Milestone 2: Vertical Slice

Goal: external testers can play without live explanation.

Deliverables:
- scenario `Found A Stable Town`;
- city levels 1-4 balanced;
- 15-18 buildings;
- 8-10 crises/events;
- policies create real tradeoffs;
- tech unlocks are visible;
- basic main menu/settings;
- Windows export build.

Exit criteria:
- 5 external testers;
- at least 3 understand next objective without Discord help;
- at least 3 can explain why they failed or succeeded.

## 5. Milestone 3: Steam Demo

Goal: public-facing validation.

Deliverables:
- demo-specific content cap;
- store page draft;
- trailer capture build;
- screenshots;
- feedback link;
- crash/bug reporting workflow;
- build naming/versioning.

Demo limits:
- one scenario;
- city levels 1-3 or 1-4;
- 45-60 minute playtime target;
- no paid DLC hooks.

Exit criteria:
- stable install/export;
- no corrupted save reports in normal path;
- enough feedback to decide Early Access vs full launch.

## 6. Milestone 4: Steam Launch

Deliverables:
- complete base game content;
- tech tree and policies in base version;
- at least 3 scenarios;
- endless mode;
- release trailer;
- store assets;
- launch discount;
- community/bug workflow.

Launch freeze:
- content freeze 14 days before launch;
- code freeze 7 days before launch;
- only critical fixes during final week.

## 7. Milestone 5: Post-Launch

First 30 days:
- hotfixes;
- UI clarity improvements;
- balance patches;
- known issues posts.

First 90 days:
- free update 1: QoL and diagnostics;
- free update 2: new events;
- free update 3: new scenario.

First paid expansion only after:
- base reviews stabilize;
- save migration is reliable;
- content pipeline supports expansion packs.

## 8. Mobile Release

Mobile starts after Steam demo or Steam launch.

Deliverables:
- touch UI;
- tablet layout;
- phone layout decision;
- billing/full unlock;
- privacy/data safety forms;
- platform-specific QA.

Launch order:
1. Android internal testing.
2. iPad TestFlight.
3. Android closed/open testing.
4. iPad release.
5. Android staged rollout.
6. Phone support if UX is acceptable.

## 9. Release Risks

High:
- UI too dense;
- simulation unclear;
- performance on mobile;
- save migration;
- monetization trust.

Mitigation:
- PC first;
- diagnostics before content bloat;
- no paid power;
- content validation;
- staged rollout.
