import SwiftUI

/// The game's UI palette, sampled from the batch-1 pixel art.
enum Pixel {
    static let bg = Color(red: 0.11, green: 0.08, blue: 0.07)
    static let panel = Color(red: 0.20, green: 0.15, blue: 0.12)
    static let panelDeep = Color(red: 0.16, green: 0.12, blue: 0.10)
    static let border = Color(red: 0.07, green: 0.05, blue: 0.04)
    static let cream = Color(red: 0.96, green: 0.90, blue: 0.78)
    static let creamDim = Color(red: 0.96, green: 0.90, blue: 0.78).opacity(0.55)
    static let human = Color(red: 0.95, green: 0.62, blue: 0.13)
    static let ai = Color(red: 0.45, green: 0.40, blue: 0.92)
    static let good = Color(red: 0.44, green: 0.76, blue: 0.35)
    static let bad = Color(red: 0.86, green: 0.32, blue: 0.26)

    static func font(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .monospaced)
    }
}

/// Flat panel with the chunky border + hard shadow the whole UI uses.
struct PixelPanel<Content: View>: View {
    var fill: Color = Pixel.panel
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(fill)
            .border(Pixel.border, width: 3)
            .background(Pixel.border.offset(x: 0, y: 5))
    }
}

/// Chunky game button: hard shadow, presses down 4pt.
struct PixelButtonStyle: ButtonStyle {
    var color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Pixel.font(16))
            .textCase(.uppercase)
            .foregroundStyle(.black.opacity(0.85))
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(color)
            .border(Pixel.border, width: 3)
            .background(
                Pixel.border.offset(x: 0, y: configuration.isPressed ? 1 : 5)
            )
            .offset(y: configuration.isPressed ? 4 : 0)
            .animation(.linear(duration: 0.05), value: configuration.isPressed)
    }
}

/// Comeback options in meeting duels: smaller, left-aligned, no shouting.
struct PixelComebackButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Pixel.font(12))
            .foregroundStyle(Pixel.cream)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(configuration.isPressed ? Pixel.panel : Pixel.panelDeep)
            .border(Pixel.border, width: 3)
            .background(Pixel.border.offset(x: 0, y: configuration.isPressed ? 1 : 4))
            .offset(y: configuration.isPressed ? 3 : 0)
            .animation(.linear(duration: 0.05), value: configuration.isPressed)
    }
}

/// Ten-block retro meter for a 0...100 score. Blocks light up one after
/// the other and the number ticks when the value changes.
struct PixelMeter: View {
    let icon: String
    let value: Int
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Text(icon).font(.system(size: 13))
            HStack(spacing: 2) {
                ForEach(0..<10, id: \.self) { block in
                    Rectangle()
                        .fill(color)
                        .opacity(block < (value + 5) / 10 ? 1 : 0.13)
                        .frame(width: 8, height: 13)
                        .animation(
                            .easeOut(duration: 0.25).delay(0.05 * Double(block)),
                            value: value
                        )
                }
            }
            .padding(3)
            .background(Pixel.panelDeep)
            .border(Pixel.border, width: 2)
            Text("\(value)")
                .font(Pixel.font(12))
                .foregroundStyle(Pixel.cream)
                .contentTransition(.numericText(value: Double(value)))
                .animation(.easeOut(duration: 0.4), value: value)
                .frame(width: 34, alignment: .leading)
        }
    }
}

/// Reveals its text one character at a time, reserving full layout space
/// so nothing jumps around while it types.
struct TypewriterText: View {
    let text: String
    let font: Font
    let color: Color
    @State private var shown = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            Text(text).opacity(0)
            Text(String(text.prefix(shown)))
        }
        .font(font)
        .foregroundStyle(color)
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .task(id: text) {
            shown = 0
            while shown < text.count {
                try? await Task.sleep(for: .milliseconds(13))
                shown += 1
            }
        }
    }
}
