# TODO

Running task list, per the GDD workflow. Current milestone: **M5 — submitted to App Review on 2026-07-17** 🚀

## Now

- [x] Art batch 4/5 integrated: counter backgrounds + consultant/angry client sprites
- [ ] Play a full campaign on a real device and tune the feel of the loop
- [x] M5: App Store metadata (EN+IT in docs/appstore/metadata.md), 6.9" screenshots (docs/appstore/screenshots/), PRIVACY.md, version 1.0.0, bundle id co.andreaios.mybossisanai
- [x] M5: ASC app record, Game Center (leaderboard + 7 achievements), metadata, screenshots, privacy, pricing — SUBMITTED for review
- [ ] Wait for App Review (typically 1–2 days); fix anything they flag
- [ ] Post-launch ideas: batch-2 Monkey Island features (insult-duel expansion, three-act structure), more tasks/events, iPad support

## Later

- [ ] M4: polish — animations, squash-and-stretch, sound gags
- [ ] M5: App Store launch prep

## Done

- [x] GDD v0.1
- [x] GitHub repository setup
- [x] `MyBossCore` Swift package: `OfficeTask`, `Consequence`, `OfficeState`, `GameEngine`, `TaskCatalog` (15 tests, TDD)
- [x] Data-driven task content (`tasks.json`, 12 tasks with gags)
- [x] Xcode project via XcodeGen (SwiftUI app + SpriteKit placeholder office scene)
- [x] Playable day loop: 3–5 tasks → Human/AI → consequence gag → day summary → campaign end
- [x] Local save/load (`save.json` in Documents, resume on launch)
- [x] M2: persistent office events (`events.json`, 7 events with thresholds), fire-once + survive save/restore
- [x] M2: campaign balance — full-AI run reaches `automated` on day 4–6, never before day 3 (test-enforced)
- [x] M2: triggered events render as persistent props in the office scene (+ fixed empty-scene rendering bug, verified via simulator screenshot)
- [x] M2: comeback events (`undoes`/`requiresAny`) — the world oscillates: Gino rehired, barista returns, memes revive (5 comeback pairs, 26 tests)
- [x] M3: 7 data-driven endings (`endings.json`), first-match-wins + exhaustive coverage test; ending screen in UI (31 tests)
- [x] M4: batch-1 pixel art integrated (backgrounds, characters, props, app icon) — sprites with nearest filtering, emoji fallback for missing art
- [x] M4: synthesized 8-bit sound gags (7 effects, `tools/make_sfx.py`), squash-and-stretch on task resolution, scene shake + haptics on events
- [x] M4: batch-2 art integrated — every event has a sprite now, no emoji fallbacks left in use
