# Authored three-act structure — design

Approved by Andrea on 2026-07-20 (chat). Layers a rising dramatic shape over
the existing emergent Human/AI campaign, without replacing the scoring system.

## Decisions locked in brainstorming

- **Adaptivity:** fixed skeleton, adaptive flavor. Beats fire on fixed days
  with a fixed structure; their text picks one of three variants by the
  player's lean. No true branching.
- **Climax:** a final best-of-three duel against the Boss-AI on the last day.
- **Mid-turn:** a narrated full-screen interstitial + a themed choice at the
  start of Act II.
- **Length:** stays 7 days, mapped 2–3–2. No balance re-tuning.

## 1. Act skeleton + lean (core, pure, TDD)

- `Act` enum: `.setup`, `.escalation`, `.climax`. `Act(for day: Int)` →
  setup for 1–2, escalation for 3–5, climax for 6–7 (day ≥ 6). Days outside
  1...campaignLength still resolve (clamp: day < 1 → setup, day > 7 → climax).
- `Lean` enum: `.human`, `.ai`, `.balanced`. `Lean.from(_ office: OfficeState)`:
  `.ai` when automation ≥ 55; else `.human` when humanity ≥ 60 and automation
  < 40; else `.balanced`. (Mirrors the stage/ending signal; no new tracking.)
- Both are pure functions, fully unit-tested.

## 2. The mid-turn beat (core data + engine)

- New model `StoryBeat` (Codable): `id`, `title`, `narration: [String: String]`
  keyed by lean raw value (`human`/`ai`/`balanced`), and two `StoryChoice`
  options (`label`, `flavorText`, `consequence: Consequence`). A helper
  `narration(for: Lean) -> String` falls back to `balanced` if a key is missing.
- `StoryBeatCatalog.loadDefault()` reads `story.json` (bundled resource, same
  pattern as tasks/events/duels). Ships one beat, `the_announcement`, with all
  three narration variants and two options ("Embrace it" / "Resist it"), each
  with a themed consequence and a small automation swing so Act II visibly
  escalates.
- `GameState.shownBeatIDs: [String]` — fired-once tracking, decoded with
  `decodeIfPresent ?? []` (backward compatible like `seed`/`duelsWon`).
- `GameEngine.midTurnBeat() -> StoryBeat?`: returns the Act-II-opening beat on
  day 3 if `!shownBeatIDs.contains(beat.id)`, else nil.
- `GameEngine.resolve(_ beat: StoryBeat, choice: StoryChoice) -> Resolution`:
  applies the choice consequence (through the normal `apply`, so it can trigger
  office events and comic stings), and records `beat.id` in `shownBeatIDs`.

## 3. The climax boss duel (core data + engine)

- Data: a dedicated boss duel in a new `boss.json` (a single `Duel`), loaded by
  `DuelCatalog.loadBoss()`. Three themed rounds against the Boss-AI (the eye),
  with `winConsequence`/`loseConsequence` **stronger** than normal duels
  (win ≈ +14 humanity / −6 automation; loss ≈ +10 automation / −10 humanity),
  so the outcome tilts which ending the pure ending-selector returns.
- `GameEngine.bossDuelForToday() -> Duel?`: returns the boss duel on the last
  day (`state.day == campaignLength`), regardless of the normal even-day
  rotation; nil otherwise. Normal `duelForToday()` is unchanged and already
  returns nil on odd day 7.
- Resolution reuses the existing `resolve(_ duel:, won:)` and `DuelBout`, so the
  win/loss consequence is applied before `finale()` runs at campaign end.
- No change to ending selection — the tilt happens through scores.

## 4. Presentation (app)

- **Act stamps:** a light "ACT I / II / III" card at each act boundary, reusing
  the existing `dayStamp` style (shown alongside the day-1/day-3/day-6 stamps).
  Subtitle line varies by lean for extra flavor.
- **Mid-turn interstitial:** a full-screen `StoryBeatView` shown at the start of
  day 3 before the workday: the beat title, the lean-selected narration, and the
  two choice buttons. Choosing resolves the beat, shows the choice's flavor +
  any triggered events, then drops into the normal day.
- **Boss duel:** flows through the existing duel UI (`currentBout`), themed by
  the boss opponent name and a comic sting ("THE BOSS AWAKENS"). The end screen
  gains a one-line epilogue reflecting the boss-duel outcome
  ("You beat the boss." / "The boss won.").
- Scene/music escalation is already stage-driven — no new work.

## 5. VM/flow wiring (app)

- `GameViewModel.Phase` gains `.storyBeat`. `beginDay()` checks
  `engine.midTurnBeat()`: if present, sets `currentBeat` and `phase = .storyBeat`
  before dealing tasks; the workday begins after the beat is answered.
- The last day's flow: after the final task, `beginDuelIfAny()` prefers
  `engine.bossDuelForToday()` over the normal `duelForToday()`; the existing
  bout → finishDay path is unchanged.
- `bossDuelWon: Bool?` on the VM feeds the epilogue line.

## Testing

- Core TDD: `Act(for:)` boundaries; `Lean.from` thresholds; `midTurnBeat`
  fires only on day 3 and only once (survives save/restore via `shownBeatIDs`);
  `resolve(beat,choice:)` applies the consequence and records the id;
  `bossDuelForToday` only on the last day; a won vs lost boss duel produces
  different final scores → different `finale()` ending; bundled `story.json`
  has all three narration variants and valid choices; `boss.json` loads with
  three valid rounds.
- App: full-campaign UI test updated for the story-beat interstitial and the
  boss duel; simulator screenshots of the interstitial and the boss duel.

## Out of scope

True branching paths, new art, changing campaign length, new endings.
