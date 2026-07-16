import SpriteKit
import MyBossCore

/// Placeholder office visualization. Real pixel art lands in Milestone 4;
/// for now the scene proves the stage-driven transformation pipeline works.
final class OfficeScene: SKScene {

    var stage: OfficeStage = .lively {
        didSet { if stage != oldValue { rebuild() } }
    }

    override func didMove(to view: SKView) {
        scaleMode = .resizeFill
        rebuild()
    }

    private func rebuild() {
        removeAllChildren()

        let (background, decorations) = look(for: stage)
        backgroundColor = background

        for (index, emoji) in decorations.enumerated() {
            let label = SKLabelNode(text: emoji)
            label.fontSize = 40
            label.position = CGPoint(
                x: size.width * (0.2 + 0.3 * CGFloat(index % 3)),
                y: size.height * (index < 3 ? 0.62 : 0.3)
            )
            label.run(.repeatForever(.sequence([
                .moveBy(x: 0, y: 6, duration: 0.5),
                .moveBy(x: 0, y: -6, duration: 0.5)
            ])))
            addChild(label)
        }
    }

    private func look(for stage: OfficeStage) -> (SKColor, [String]) {
        switch stage {
        case .lively:
            (SKColor(red: 0.98, green: 0.92, blue: 0.80, alpha: 1), ["🧑‍💼", "👩‍💼", "🪴", "☕️", "🖨️", "🍕"])
        case .hybrid:
            (SKColor(red: 0.85, green: 0.88, blue: 0.94, alpha: 1), ["🧑‍💼", "🤖", "🪴", "🦾", "🖨️", "📡"])
        case .automated:
            (SKColor(red: 0.70, green: 0.75, blue: 0.85, alpha: 1), ["🤖", "🤖", "🛸", "🦾", "📉", "🔌"])
        }
    }
}
