# Authored Three-Act Structure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the 7-day campaign a rising three-act shape — a mid-campaign narrated turn and a final Boss-AI duel — layered over the existing emergent scoring, with adaptive flavor.

**Architecture:** Act/lean logic and the new story-beat + boss-duel content live in `MyBossCore` (pure, Swift Testing, TDD). The interstitial, act stamps, and boss-duel wiring live in `App/` (SwiftUI), verified by build + the full-campaign XCUITest + screenshots. Content stays data-driven JSON in `MyBossCore/Sources/MyBossCore/Resources/`.

**Tech Stack:** Swift 6, SwiftUI, SpriteKit, Swift Testing, XcodeGen, XCUITest.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-20-three-acts-design.md`.
- Core tests: `cd MyBossCore && swift test`. App: `xcodegen generate` after adding files, then `xcodebuild -project MyBossIsAnAI.xcodeproj -scheme MyBossIsAnAI -destination 'platform=iOS Simulator,id=9FAE1948-588D-4D0D-852E-9F75F3983F96'`.
- Campaign stays 7 days, 2–3–2. No balance re-tuning, no new endings, no new art.
- `GameState` additions decode with `decodeIfPresent` (backward compatible).
- Fixed skeleton, adaptive flavor: beats fire on fixed days; text varies by lean.
- Comedy-first copy in the established office voice.

---

### Task 1: Act + Lean (core)

**Files:**
- Create: `MyBossCore/Sources/MyBossCore/Act.swift`
- Test: `MyBossCore/Tests/MyBossCoreTests/ActTests.swift`

**Interfaces:**
- Produces: `enum Act { case setup, escalation, climax }`, `Act(for day: Int) -> Act`; `enum Lean: String { case human, ai, balanced }`, `Lean.from(_ office: OfficeState) -> Lean`.

- [ ] **Step 1: failing tests**

```swift
import Testing
@testable import MyBossCore

@Suite("Acts and lean")
struct ActTests {
    @Test("days map to the 2-3-2 act skeleton")
    func actBoundaries() {
        #expect(Act(for: 1) == .setup)
        #expect(Act(for: 2) == .setup)
        #expect(Act(for: 3) == .escalation)
        #expect(Act(for: 5) == .escalation)
        #expect(Act(for: 6) == .climax)
        #expect(Act(for: 7) == .climax)
    }

    @Test("out-of-range days clamp to the nearest act")
    func actClamp() {
        #expect(Act(for: 0) == .setup)
        #expect(Act(for: 99) == .climax)
    }

    private func office(auto: Int, human: Int) -> OfficeState {
        var o = OfficeState()
        // OfficeState starts at automation 0, humanity 100.
        o.apply(Consequence(eventID: "", flavorText: "", automationDelta: auto, humanityDelta: human - 100))
        return o
    }

    @Test("lean reads the accumulated scores")
    func lean() {
        #expect(Lean.from(office(auto: 70, human: 20)) == .ai)
        #expect(Lean.from(office(auto: 10, human: 90)) == .human)
        #expect(Lean.from(office(auto: 45, human: 55)) == .balanced)
    }
}
```

- [ ] **Step 2: run, expect FAIL.** `swift test --filter ActTests`.
- [ ] **Step 3: implement** — `Act.swift`:

```swift
/// The dramatic act a given campaign day belongs to (2–3–2 over 7 days).
public enum Act: Sendable, Equatable {
    case setup, escalation, climax
}

public func Act(for day: Int) -> Act {
    switch day {
    case ..<3: .setup
    case 3...5: .escalation
    default: .climax
    }
}

/// How the player has been leaning, read from the accumulated office scores —
/// the same signal that drives stages and endings, so no extra tracking.
public enum Lean: String, Sendable, Equatable {
    case human, ai, balanced

    public static func from(_ office: OfficeState) -> Lean {
        if office.automation >= 55 { return .ai }
        if office.humanity >= 60 && office.automation < 40 { return .human }
        return .balanced
    }
}
```

- [ ] **Step 4: run, expect PASS.**
- [ ] **Step 5: commit** `feat(core): Act skeleton and Lean`.

### Task 2: StoryBeat model + catalog + story.json (core)

**Files:**
- Create: `MyBossCore/Sources/MyBossCore/StoryBeat.swift`, `MyBossCore/Sources/MyBossCore/Resources/story.json`
- Test: `MyBossCore/Tests/MyBossCoreTests/StoryBeatTests.swift`

**Interfaces:**
- Consumes: `Lean` (Task 1), `Consequence`.
- Produces: `StoryChoice(label:flavorText:consequence:)`; `StoryBeat(id:title:narration:choices:)` with `narration(for: Lean) -> String`; `StoryBeatCatalog.decode(from:)` / `.loadDefault()`.

- [ ] **Step 1: failing tests**

```swift
import Foundation
import Testing
@testable import MyBossCore

@Suite("Story beats")
struct StoryBeatTests {
    private func beat() -> StoryBeat {
        StoryBeat(
            id: "b",
            title: "The Announcement",
            narration: ["human": "H", "ai": "A", "balanced": "B"],
            choices: [
                StoryChoice(label: "Embrace", flavorText: "e", consequence: Consequence(eventID: "e", flavorText: "", automationDelta: 6, humanityDelta: -4)),
                StoryChoice(label: "Resist", flavorText: "r", consequence: Consequence(eventID: "r", flavorText: "", automationDelta: -4, humanityDelta: 4))
            ]
        )
    }

    @Test("narration picks the variant for the lean")
    func narrationByLean() {
        #expect(beat().narration(for: .ai) == "A")
        #expect(beat().narration(for: .human) == "H")
    }

    @Test("a missing variant falls back to balanced")
    func narrationFallback() {
        let b = StoryBeat(id: "b", title: "t", narration: ["balanced": "B"], choices: beat().choices)
        #expect(b.narration(for: .ai) == "B")
    }

    @Test("bundled story.json has the announcement with all three variants")
    func bundled() throws {
        let beats = try StoryBeatCatalog.loadDefault()
        let announcement = try #require(beats.first { $0.id == "the_announcement" })
        for lean in ["human", "ai", "balanced"] {
            #expect(announcement.narration[lean]?.isEmpty == false)
        }
        #expect(announcement.choices.count == 2)
    }
}
```

- [ ] **Step 2: run, expect FAIL.**
- [ ] **Step 3: implement** — `StoryBeat.swift`:

```swift
import Foundation

/// One option in a story beat: a labelled choice with its own gag and score
/// consequence.
public struct StoryChoice: Codable, Equatable, Sendable {
    public let label: String
    public let flavorText: String
    public let consequence: Consequence

    public init(label: String, flavorText: String, consequence: Consequence) {
        self.label = label
        self.flavorText = flavorText
        self.consequence = consequence
    }
}

/// An authored narrative beat (e.g. the mid-campaign turn). The skeleton is
/// fixed; the narration adapts to the player's lean.
public struct StoryBeat: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let narration: [String: String]
    public let choices: [StoryChoice]

    public init(id: String, title: String, narration: [String: String], choices: [StoryChoice]) {
        self.id = id
        self.title = title
        self.narration = narration
        self.choices = choices
    }

    public func narration(for lean: Lean) -> String {
        narration[lean.rawValue] ?? narration["balanced"] ?? ""
    }
}

public enum StoryBeatCatalog {
    public static func decode(from data: Data) throws -> [StoryBeat] {
        try JSONDecoder().decode([StoryBeat].self, from: data)
    }

    public static func loadDefault() throws -> [StoryBeat] {
        guard let url = Bundle.module.url(forResource: "story", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try decode(from: Data(contentsOf: url))
    }
}
```

- [ ] **Step 4: write `story.json`** — one beat `the_announcement`, `title` "THE ANNOUNCEMENT", three narration variants in the office voice (human: management notices you're doing everything by hand and is "concerned"; ai: management is thrilled and doubles down; balanced: a vague reorg nobody understands), and two choices ("Embrace the future" → automation +6/humanity −4, flavor about signing on; "Quietly resist" → automation −4/humanity +4, flavor about slow-walking it). All strings comedic.
- [ ] **Step 5: run, expect PASS; commit** `feat(core): StoryBeat model, catalog, the_announcement`.

### Task 3: shownBeatIDs + engine mid-turn hooks (core)

**Files:**
- Modify: `MyBossCore/Sources/MyBossCore/GameEngine.swift`
- Test: `MyBossCore/Tests/MyBossCoreTests/MidTurnTests.swift`

**Interfaces:**
- Consumes: `StoryBeat`/`StoryChoice` (Task 2).
- Produces: `GameState.shownBeatIDs: [String]`; `GameEngine` gains a `beats:` init param, `midTurnBeat() -> StoryBeat?`, `resolve(_ beat: StoryBeat, choice: StoryChoice) -> Resolution`.

- [ ] **Step 1: failing tests**

```swift
import Foundation
import Testing
@testable import MyBossCore

@Suite("Mid-turn beat")
struct MidTurnTests {
    private func catalog() -> [OfficeTask] {
        (0..<10).map { i in OfficeTask(id: "t\(i)", title: "T", humanConsequence: Consequence(eventID: "h", flavorText: "", automationDelta: -3, humanityDelta: 4), aiConsequence: Consequence(eventID: "a", flavorText: "", automationDelta: 5, humanityDelta: -4)) }
    }
    private func beat() -> StoryBeat {
        StoryBeat(id: "the_announcement", title: "T",
            narration: ["balanced": "B"],
            choices: [StoryChoice(label: "x", flavorText: "", consequence: Consequence(eventID: "c", flavorText: "", automationDelta: 6, humanityDelta: 0))])
    }
    private func play(_ e: GameEngine) { for t in e.startDay() { _ = e.resolve(t, with: .ai) }; e.endDay() }

    @Test("the beat is offered only on day 3")
    func onlyDay3() {
        let e = GameEngine(catalog: catalog(), seed: 1, beats: [beat()])
        #expect(e.midTurnBeat() == nil)          // day 1
        play(e); #expect(e.midTurnBeat() == nil) // day 2
        play(e); #expect(e.midTurnBeat()?.id == "the_announcement") // day 3
    }

    @Test("resolving records it so it never fires twice")
    func firesOnce() {
        let e = GameEngine(catalog: catalog(), seed: 1, beats: [beat()])
        play(e); play(e) // day 3
        _ = e.resolve(beat(), choice: beat().choices[0])
        #expect(e.state.shownBeatIDs.contains("the_announcement"))
        #expect(e.midTurnBeat() == nil)
    }

    @Test("the choice consequence moves the office")
    func choiceApplies() {
        let e = GameEngine(catalog: catalog(), seed: 1, beats: [beat()])
        play(e); play(e)
        let before = e.state.office.automation
        _ = e.resolve(beat(), choice: beat().choices[0])
        #expect(e.state.office.automation == before + 6)
    }

    @Test("shownBeatIDs survives a save/restore")
    func persists() throws {
        let e = GameEngine(catalog: catalog(), seed: 1, beats: [beat()])
        play(e); play(e)
        _ = e.resolve(beat(), choice: beat().choices[0])
        let saved = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(e.state))
        #expect(saved.shownBeatIDs.contains("the_announcement"))
    }
}
```

- [ ] **Step 2: run, expect FAIL.**
- [ ] **Step 3: implement** —
  - In `GameState`: add `public var shownBeatIDs: [String]`; init sets `shownBeatIDs = []`; `init(from:)` adds `shownBeatIDs = try container.decodeIfPresent([String].self, forKey: .shownBeatIDs) ?? []`.
  - In `GameEngine`: add stored `private let beats: [StoryBeat]`; add `beats: [StoryBeat] = []` to BOTH inits and assign; add:

```swift
/// The Act-II-opening beat: offered once, on day 3.
public func midTurnBeat() -> StoryBeat? {
    guard state.day == 3 else { return nil }
    return beats.first { !state.shownBeatIDs.contains($0.id) }
}

public func resolve(_ beat: StoryBeat, choice: StoryChoice) -> Resolution {
    state.shownBeatIDs.append(beat.id)
    return apply(choice.consequence)
}
```

- [ ] **Step 4: run, expect PASS; commit** `feat(core): mid-turn story beat scheduling`.

### Task 4: Boss duel climax (core)

**Files:**
- Create: `MyBossCore/Sources/MyBossCore/Resources/boss.json`
- Modify: `MyBossCore/Sources/MyBossCore/Duel.swift` (`DuelCatalog.loadBoss`), `GameEngine.swift` (`bossDuelForToday`)
- Test: `MyBossCore/Tests/MyBossCoreTests/BossDuelTests.swift`

**Interfaces:**
- Produces: `DuelCatalog.loadBoss() throws -> Duel`; `GameEngine.bossDuelForToday() -> Duel?`.

- [ ] **Step 1: failing tests**

```swift
import Foundation
import Testing
@testable import MyBossCore

@Suite("Boss duel climax")
struct BossDuelTests {
    private func catalog() -> [OfficeTask] {
        (0..<10).map { i in OfficeTask(id: "t\(i)", title: "T", humanConsequence: Consequence(eventID: "h", flavorText: "", automationDelta: -3, humanityDelta: 4), aiConsequence: Consequence(eventID: "a", flavorText: "", automationDelta: 5, humanityDelta: -4)) }
    }
    private func boss() -> Duel {
        Duel(id: "boss", opponent: "The Boss-AI",
            rounds: (1...3).map { DuelRound(provocation: "P\($0)", comebacks: ["a","b","c"], correctIndex: 1) },
            winConsequence: Consequence(eventID: "bw", flavorText: "", automationDelta: -6, humanityDelta: 14),
            loseConsequence: Consequence(eventID: "bl", flavorText: "", automationDelta: 10, humanityDelta: -10))
    }
    private func play(_ e: GameEngine) { for t in e.startDay() { _ = e.resolve(t, with: .ai) }; e.endDay() }

    @Test("the boss duel is scheduled only on the last day")
    func lastDayOnly() {
        let e = GameEngine(catalog: catalog(), seed: 1, campaignLength: 7, bossDuel: boss())
        for _ in 1...6 { #expect(e.bossDuelForToday() == nil); play(e) }
        #expect(e.bossDuelForToday()?.id == "boss") // day 7
    }

    @Test("winning vs losing the boss duel changes the final scores")
    func tiltsEnding() {
        func finalHumanity(won: Bool) -> Int {
            let e = GameEngine(catalog: catalog(), seed: 1, campaignLength: 7, bossDuel: boss())
            for _ in 1...6 { play(e) }
            _ = e.resolve(boss(), won: won)
            return e.state.office.humanity
        }
        #expect(finalHumanity(won: true) > finalHumanity(won: false))
    }

    @Test("bundled boss loads with three valid rounds")
    func bundled() throws {
        let boss = try DuelCatalog.loadBoss()
        #expect(boss.rounds.count == 3)
        for r in boss.rounds { #expect(r.comebacks.indices.contains(r.correctIndex)) }
    }
}
```

- [ ] **Step 2: run, expect FAIL.**
- [ ] **Step 3: implement** —
  - `boss.json`: a single JSON object (not an array) — one `Duel` with id `boss`, opponent "The Boss-AI", three themed rounds against the eye, stronger win/loss consequences (win −6 auto / +14 humanity; loss +10 auto / −10 humanity).
  - `DuelCatalog.loadBoss()`:

```swift
public static func loadBoss() throws -> Duel {
    guard let url = Bundle.module.url(forResource: "boss", withExtension: "json") else {
        throw CocoaError(.fileNoSuchFile)
    }
    return try JSONDecoder().decode(Duel.self, from: Data(contentsOf: url))
}
```

  - `GameEngine`: add stored `private let bossDuel: Duel?`; add `bossDuel: Duel? = nil` to BOTH inits and assign; add:

```swift
/// The climax duel against the Boss-AI, scheduled on the last day only.
public func bossDuelForToday() -> Duel? {
    state.day == campaignLength ? bossDuel : nil
}
```

  Note: `campaignLength` is on `state`; reference `state.campaignLength`.
- [ ] **Step 4: run, expect PASS; commit** `feat(core): Boss-AI climax duel on the last day`.

### Task 5: Story-beat interstitial + VM flow (app)

**Files:**
- Create: `App/StoryBeatView.swift`
- Modify: `App/GameViewModel.swift`, `App/GameView.swift`

**Interfaces:**
- Consumes: `midTurnBeat()`, `resolve(_:choice:)`, `Lean` (via `Lean.from(office)`).
- Produces: VM `Phase.storyBeat`, `currentBeat: StoryBeat?`, `beatNarration: String`, `answerBeat(_ choice: StoryChoice)`.

- [ ] **Step 1: load the catalog** — in `GameViewModel.init`, add `beats = (try? StoryBeatCatalog.loadDefault()) ?? []` and store `private let beats: [StoryBeat]`; pass `beats: beats` into both `GameEngine(...)` calls (fresh + resume).
- [ ] **Step 2: VM phase + flow** —
  - Add `case storyBeat` to `enum Phase`.
  - Add `private(set) var currentBeat: StoryBeat?`.
  - Add computed `var beatNarration: String { currentBeat.map { $0.narration(for: Lean.from(engine.state.office)) } ?? "" }`.
  - In `beginDay()`, after dealing tasks, before returning:

```swift
if let beat = engine.midTurnBeat() {
    currentBeat = beat
    phase = .storyBeat
    return
}
phase = .workday
```

  (Move the existing `phase = .workday` so the beat check can override it; tasks are already dealt.)
  - Add:

```swift
func answerBeat(_ choice: StoryChoice) {
    guard let beat = currentBeat else { return }
    lastResolution = engine.resolve(beat, choice: choice)
    currentBeat = nil
    phase = .workday
    save()
}
```

  Clear `currentBeat = nil` in `restartCampaign()`.
- [ ] **Step 3: StoryBeatView** — `App/StoryBeatView.swift`, a full-screen overlay:

```swift
import SwiftUI
import MyBossCore

struct StoryBeatView: View {
    let beat: StoryBeat
    let narration: String
    let onChoose: (StoryChoice) -> Void

    var body: some View {
        ZStack {
            Pixel.bg.opacity(0.94).ignoresSafeArea()
            PixelPanel {
                VStack(spacing: 18) {
                    Text("📣 \(beat.title)")
                        .font(Pixel.font(18))
                        .foregroundStyle(Pixel.bad)
                        .multilineTextAlignment(.center)
                    Text(narration)
                        .font(Pixel.font(13))
                        .foregroundStyle(Pixel.cream)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(beat.choices.indices, id: \.self) { i in
                        Button(beat.choices[i].label) {
                            SoundPlayer.shared.play(.tap)
                            onChoose(beat.choices[i])
                        }
                        .buttonStyle(PixelButtonStyle(color: i == 0 ? Pixel.ai : Pixel.human))
                    }
                }
                .padding(22)
            }
            .padding(.horizontal, 26)
        }
        .transition(.opacity)
    }
}
```

- [ ] **Step 4: present it in GameView** — in the overlay `ZStack`, add:

```swift
if model.phase == .storyBeat, let beat = model.currentBeat {
    StoryBeatView(beat: beat, narration: model.beatNarration) { choice in
        model.answerBeat(choice)
        playResolutionEffects(for: .human)
    }
    .zIndex(3)
}
```

- [ ] **Step 5: build, then commit** `feat: mid-turn story-beat interstitial`.

### Task 6: Boss duel wiring + epilogue + act stamps (app)

**Files:**
- Modify: `App/GameViewModel.swift`, `App/GameView.swift`

**Interfaces:**
- Consumes: `bossDuelForToday()`.
- Produces: VM `bossDuelWon: Bool?`; GameView act-stamp + epilogue.

- [ ] **Step 1: load boss + schedule** — in `GameViewModel.init`, `bossDuel = try? DuelCatalog.loadBoss()`, store `private let bossDuel: Duel?`, pass `bossDuel: bossDuel` into both `GameEngine(...)` calls. In `advanceAfterConsequence()`, replace the duel-start block:

```swift
if currentTaskIndex >= todaysTasks.count {
    if let duel = engine.bossDuelForToday() ?? engine.duelForToday() {
        currentBout = DuelBout(duel: duel)
        lastRoundLanded = nil
        phase = .duel
    } else {
        finishDay()
    }
}
```

- [ ] **Step 2: track boss outcome** — add `private(set) var bossDuelWon: Bool?`. In `fight(comebackIndex:)`, when `bout.isOver`, set `if bout.duel.id == "boss" { bossDuelWon = bout.won }`. Clear in `restartCampaign()`.
- [ ] **Step 3: epilogue on the end screen** — in `endingOverlay`, after the ending flavor `ScrollView`, before the daily-score block:

```swift
if let won = model.bossDuelWon {
    Text(won ? "🏆 You beat the boss." : "💀 The boss won.")
        .font(Pixel.font(13))
        .foregroundStyle(won ? Pixel.human : Pixel.bad)
}
```

- [ ] **Step 4: act stamp** — add to GameView `@State private var actStamp: String?` and a helper mirroring `showDayStamp`:

```swift
private func showActStamp(_ text: String) {
    withAnimation(.spring(duration: 0.4)) { actStamp = text }
    Task {
        try? await Task.sleep(for: .seconds(1.4))
        withAnimation(.easeOut(duration: 0.3)) { actStamp = nil }
    }
}
```

Render it under the day stamp:

```swift
if let act = actStamp {
    Text(act)
        .font(Pixel.font(30))
        .foregroundStyle(Pixel.cream)
        .padding(.horizontal, 22).padding(.vertical, 10)
        .background(Pixel.panel).border(Pixel.border, width: 3)
        .offset(y: 60)
        .transition(.scale.combined(with: .opacity))
        .allowsHitTesting(false)
}
```

Trigger it when the act changes: add a VM computed `var actLabel: String { switch Act(for: day) { case .setup: "ACT I"; case .escalation: "ACT II"; case .climax: "ACT III" } }`, and in GameView's `showDayStamp` callers for days 1/3/6 call `showActStamp(model.actLabel)` right after `showDayStamp`. Simplest: in `.onChange(of: model.day)`, when `model.day == 1 || model.day == 3 || model.day == 6`, call `showActStamp(model.actLabel)`. (Add an `.onChange(of: model.day)` if none exists.)
- [ ] **Step 5: boss sting** — in `fightDuel`, when the bout's duel id is `boss` and the bout just started (first round, `bout.wins + bout.losses == 0`), call `scene.spawnComicText("THE BOSS AWAKENS")`. Keep it simple: call it once when entering `.duel` with a boss duel — in `advanceAfterConsequence`, right after setting `phase = .duel`, `if currentBout?.duel.id == "boss" { }` is VM-side; instead trigger in GameView `.onChange(of: model.phase)` when phase becomes `.duel` and `model.currentBout?.duel.id == "boss"`: `scene.spawnComicText("THE BOSS AWAKENS")`.
- [ ] **Step 6: build, then commit** `feat: boss-duel climax, act stamps, epilogue`.

### Task 7: UI test + verification + bookkeeping

**Files:**
- Modify: `UITests/CampaignUITests.swift`, `TODO.md`, auto-memory

- [ ] **Step 1: UI test** — the story-beat interstitial shows two unlabeled-to-the-test buttons; add their handling: before the duel-comeback fallback, tap the first hittable non-known button when `model.phase` can't be read — actually the existing "unknown button" fallback already taps story-beat choices and boss-duel comebacks, since they aren't in `knownLabels`. Add `"THE BOSS AWAKENS"` is a scene label (not a button) so no change. Confirm the loop still reaches "PLAY AGAIN ▸". No new known labels required, but add the two story choice labels are dynamic; leave the generic fallback to handle them.
- [ ] **Step 2: run full campaign UI test** — `xcodebuild test … -only-testing:MyBossIsAnAIUITests/CampaignUITests/testFullCampaign`. Expected: `** TEST SUCCEEDED **`. If it stalls on the interstitial, ensure the generic "first hittable unknown button" tap covers story choices (it does, since they're plain buttons with labels not in `knownLabels`).
- [ ] **Step 3: core tests** — `cd MyBossCore && swift test`. Expected: all green.
- [ ] **Step 4: screenshots** — seeded showcase at day 3 (interstitial) and day 7 (boss duel) via the `testShowcase` harness.
- [ ] **Step 5: bookkeeping** — tick the three-act item in `TODO.md`; update the auto-memory status paragraph; commit `feat: authored three-act structure — turn, boss climax, act stamps`.

## Self-review notes

- Spec §1→T1, §2→T2+T3, §3→T4, §4 presentation→T5+T6, §5 wiring→T5+T6, testing→T7. Covered.
- Types: `Act`/`Lean` (T1)→T2/T5/T6; `StoryBeat`/`StoryChoice` (T2)→T3/T5; `shownBeatIDs`/`midTurnBeat`/`resolve(beat,choice:)` (T3)→T5; `loadBoss`/`bossDuelForToday` (T4)→T6. Consistent.
- Both `GameEngine` inits get `beats:` (T3) and `bossDuel:` (T4) params with defaults — existing call sites unaffected; App passes them in T5/T6.
- Placeholder scan: none.
