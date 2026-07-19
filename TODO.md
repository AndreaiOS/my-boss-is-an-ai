# TODO

Running task list, per the GDD workflow. Current milestone: **v1.1 in progress** (v1.0.0 submitted to App Review on 2026-07-17 🚀)

## Now

- [x] v1.1: best-of-3 meeting duels — `DuelRound`/`DuelBout` in core, duels.json migrated to rounds (6 duels × 3 rounds), engine `resolve(duel, won:)` (47 core tests)
- [x] v1.1: learned comebacks (Monkey Island rules) — losing a round marks the right answer with ★ forever (`ComebackSchool`, UserDefaults)
- [x] v1.1: daily challenge — shared UTC date seed (`DailySeed`), title-screen button, score = humanity×2 + 25×duelsWon submitted to GC leaderboard `daily_challenge`; v1.0 saves still load
- [x] v1.1: more content — 7 consultant offers, 24 AI remarks; bump to 1.1.0
- [ ] v1.1: create the `daily_challenge` recurring leaderboard in ASC (checklist.md §2) before submitting 1.1.0
- [ ] Play a full campaign on a real device and tune the feel of the loop
- [ ] Wait for App Review of v1.0.0 (typically 1–2 days); fix anything they flag
- [ ] Post-launch ideas: three-act structure, more tasks/events, iPad support

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
