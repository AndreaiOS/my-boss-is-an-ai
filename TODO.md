# TODO

Running task list, per the GDD workflow. Current milestone: **M1 — Playable prototype**.

## Now

- [ ] Run the prototype on a simulator/device and tune the feel of the loop
- [ ] Reflect triggered office events in the SpriteKit scene (persistent props: robot cleaner, Gino's mug…)
- [ ] Comeback events (automation dropping back down: "Gino is rehired. The mug is reunited.")
- [ ] First real pixel-art sprite to replace one emoji placeholder

## Later

- [ ] M3: multiple endings (full-AI, full-human, hybrids)
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
