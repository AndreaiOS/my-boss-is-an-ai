import SwiftUI

/// The WarioWare micro-gags: 3–5 second interactions that play when the
/// player chooses to do certain tasks by hand. Winning nudges humanity up;
/// losing only changes the punchline. Comedy first, never punishment.
enum MicroGameKind: String {
    case printerSmash = "printer_smash"
    case coffeeRush = "coffee_rush"
    case findLasagna = "find_lasagna"

    init?(id: String) {
        self.init(rawValue: id)
    }

    var title: String {
        switch self {
        case .printerSmash: "PERCUSSIVE MAINTENANCE"
        case .coffeeRush: "THE COFFEE RUN"
        case .findLasagna: "FIND 'LASAGNA'"
        }
    }

    var instructions: String {
        switch self {
        case .printerSmash: "Whack the printer 8 times. It respects strength."
        case .coffeeRush: "Stop the tray in the middle. Twice. No spills."
        case .findLasagna: "One cell is sacred. Tap it before the AI does."
        }
    }

    var successLine: String {
        switch self {
        case .printerSmash: "The printer purrs. You are the office wizard."
        case .coffeeRush: "Nine coffees, zero spills. A standing ovation."
        case .findLasagna: "'lasagna' is safe. The spreadsheet has a soul again."
        }
    }

    var failureLine: String {
        switch self {
        case .printerSmash: "The printer looked at you funny. You blinked first."
        case .coffeeRush: "Two cappuccinos became one floor-uccino. Respect for trying."
        case .findLasagna: "Time's up. 'lasagna' spends one more night alone. It forgives you."
        }
    }
}

/// Full-screen overlay hosting whichever micro-game is active.
struct MicroGameOverlay: View {
    let kind: MicroGameKind
    let onFinish: (Bool) -> Void

    var body: some View {
        ZStack {
            Pixel.bg.opacity(0.92).ignoresSafeArea()
            PixelPanel {
                VStack(spacing: 14) {
                    Text("🎮 \(kind.title)")
                        .font(Pixel.font(15))
                        .foregroundStyle(Pixel.bad)
                    Text(kind.instructions)
                        .font(Pixel.font(11))
                        .foregroundStyle(Pixel.creamDim)
                        .multilineTextAlignment(.center)
                    switch kind {
                    case .printerSmash: PrinterSmashView(onFinish: onFinish)
                    case .coffeeRush: CoffeeRushView(onFinish: onFinish)
                    case .findLasagna: FindLasagnaView(onFinish: onFinish)
                    }
                }
                .padding(18)
            }
            .padding(.horizontal, 26)
        }
        .transition(.scale(scale: 1.15).combined(with: .opacity))
    }
}

/// Shared countdown bar; the game is over when it empties.
private struct CountdownBar: View {
    let start: Date
    let duration: TimeInterval

    var body: some View {
        TimelineView(.animation) { context in
            let remaining = max(0, duration - context.date.timeIntervalSince(start))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Pixel.bg)
                    Rectangle()
                        .fill(remaining < duration * 0.3 ? Pixel.bad : Pixel.human)
                        .frame(width: geo.size.width * remaining / duration)
                }
            }
        }
        .frame(height: 10)
        .border(Pixel.border, width: 2)
    }
}

/// Tap the printer 8 times in 3 seconds. Violence, as documented, works.
private struct PrinterSmashView: View {
    let onFinish: (Bool) -> Void
    @State private var start = Date()
    @State private var hits = 0
    @State private var finished = false

    private let target = 8
    private let duration: TimeInterval = 3

    var body: some View {
        VStack(spacing: 12) {
            CountdownBar(start: start, duration: duration)
            Text("\(hits)/\(target)")
                .font(Pixel.font(16))
                .foregroundStyle(Pixel.cream)
            Button("🖨") {
                guard !finished else { return }
                hits += 1
                Haptics.impact()
                SoundPlayer.shared.play(.tap)
                if hits >= target { finish(true) }
            }
            .font(.system(size: 56))
            .padding(18)
            .background(Pixel.panel)
            .border(Pixel.border, width: 3)
        }
        .task {
            try? await Task.sleep(for: .seconds(duration))
            finish(false)
        }
    }

    private func finish(_ won: Bool) {
        guard !finished else { return }
        finished = true
        onFinish(won)
    }
}

/// A tray sweeps left-right: stop it in the middle zone, 2 hits out of 3.
private struct CoffeeRushView: View {
    let onFinish: (Bool) -> Void
    @State private var start = Date()
    @State private var attempts = 0
    @State private var hitCount = 0
    @State private var finished = false

    private let duration: TimeInterval = 5
    private let sweep: TimeInterval = 0.9
    private let zone: ClosedRange<Double> = 0.36...0.64

    /// 0→1→0 triangle wave, one full sweep per 2×`sweep` seconds.
    private func cursor(at date: Date) -> Double {
        let t = date.timeIntervalSince(start).truncatingRemainder(dividingBy: sweep * 2)
        return t < sweep ? t / sweep : 2 - t / sweep
    }

    var body: some View {
        VStack(spacing: 12) {
            CountdownBar(start: start, duration: duration)
            Text("☕️ \(hitCount)/2 · tries \(attempts)/3")
                .font(Pixel.font(12))
                .foregroundStyle(Pixel.cream)
            TimelineView(.animation) { context in
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Pixel.bg)
                        Rectangle()
                            .fill(Pixel.human.opacity(0.4))
                            .frame(width: geo.size.width * (zone.upperBound - zone.lowerBound))
                            .offset(x: geo.size.width * zone.lowerBound)
                        Text("🫖")
                            .font(.system(size: 22))
                            .offset(x: geo.size.width * cursor(at: context.date) - 11)
                    }
                }
            }
            .frame(height: 30)
            .border(Pixel.border, width: 2)
            Button("STOP!") {
                guard !finished, attempts < 3 else { return }
                attempts += 1
                Haptics.impact()
                if zone.contains(cursor(at: Date())) {
                    hitCount += 1
                    SoundPlayer.shared.play(.eventGood)
                } else {
                    SoundPlayer.shared.play(.tap)
                }
                if hitCount >= 2 { finish(true) } else if attempts >= 3 { finish(false) }
            }
            .buttonStyle(PixelButtonStyle(color: Pixel.bad))
        }
        .task {
            try? await Task.sleep(for: .seconds(duration))
            finish(false)
        }
    }

    private func finish(_ won: Bool) {
        guard !finished else { return }
        finished = true
        onFinish(won)
    }
}

/// A 4×4 grid of corporate junk. One cell says 'lasagna'. Protect it.
private struct FindLasagnaView: View {
    let onFinish: (Bool) -> Void
    @State private var start = Date()
    @State private var finished = false
    @State private var cells: [String] = {
        var junk = ["#REF!", "Q3", "synergy", "€0", "N/A", "TODO", "0.07%", "FY26", "≈4", "#DIV/0!", "OKR", "π?", "…", "v2_final", "meh"]
        junk.shuffle()
        var grid = Array(junk.prefix(15))
        grid.insert("lasagna", at: Int.random(in: 0..<16))
        return grid
    }()

    private let duration: TimeInterval = 4
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)

    var body: some View {
        VStack(spacing: 12) {
            CountdownBar(start: start, duration: duration)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(cells.indices, id: \.self) { index in
                    Button(cells[index]) {
                        guard !finished else { return }
                        if cells[index] == "lasagna" {
                            SoundPlayer.shared.play(.eventGood)
                            finish(true)
                        } else {
                            Haptics.impact()
                            cells[index] = "✖︎"
                        }
                    }
                    .font(Pixel.font(9))
                    .foregroundStyle(cells[index] == "✖︎" ? Pixel.creamDim : Pixel.cream)
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .background(Pixel.panel)
                    .border(Pixel.border, width: 2)
                }
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(duration))
            finish(false)
        }
    }

    private func finish(_ won: Bool) {
        guard !finished else { return }
        finished = true
        onFinish(won)
    }
}
