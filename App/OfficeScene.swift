import SpriteKit
import MyBossCore

/// Placeholder office visualization. Real pixel art lands in Milestone 4;
/// for now the scene proves the stage-driven transformation pipeline works.
final class OfficeScene: SKScene {

    private var stage: OfficeStage = .lively
    private var eventIDs: [String] = []

    /// How a triggered office event shows up in the scene, permanently.
    private struct Prop {
        let emoji: String
        /// Relative position in the scene (0...1).
        let x: CGFloat
        let y: CGFloat
        let animation: SKAction?
    }

    private static let props: [String: Prop] = [
        "robot_cleaner": Prop(
            emoji: "🤖", x: 0.15, y: 0.08,
            animation: .repeatForever(.sequence([
                .moveBy(x: 60, y: 0, duration: 2.5),
                .moveBy(x: -60, y: 0, duration: 2.5)
            ]))
        ),
        "layoff_gino": Prop(
            emoji: "🪑☕️", x: 0.85, y: 0.12,
            animation: .repeatForever(.sequence([
                .fadeAlpha(to: 0.5, duration: 1.5),
                .fadeAlpha(to: 1.0, duration: 1.5)
            ]))
        ),
        "ai_coffee_machine": Prop(
            emoji: "☕️🦾", x: 0.08, y: 0.45,
            animation: .repeatForever(.sequence([
                .scale(to: 1.15, duration: 0.4),
                .scale(to: 1.0, duration: 0.4),
                .wait(forDuration: 2)
            ]))
        ),
        "manager_algorithm": Prop(
            emoji: "📊", x: 0.5, y: 0.82,
            animation: .repeatForever(.rotate(byAngle: .pi * 2, duration: 8))
        ),
        "coworkers_bots": Prop(
            emoji: "🦾🦾", x: 0.65, y: 0.12,
            animation: nil
        ),
        "memes_die": Prop(
            emoji: "📉", x: 0.92, y: 0.8,
            animation: nil
        ),
        "plant_funeral": Prop(
            emoji: "🥀", x: 0.3, y: 0.12,
            animation: .repeatForever(.sequence([
                .rotate(byAngle: -0.15, duration: 2),
                .rotate(byAngle: 0.15, duration: 2)
            ]))
        ),
        "gino_rehired": Prop(
            emoji: "🧔☕️", x: 0.85, y: 0.12,
            animation: .repeatForever(.sequence([
                .moveBy(x: 0, y: 8, duration: 0.3),
                .moveBy(x: 0, y: -8, duration: 0.3),
                .wait(forDuration: 1.5)
            ]))
        ),
        "barista_returns": Prop(
            emoji: "🧋", x: 0.08, y: 0.45,
            animation: .repeatForever(.sequence([
                .rotate(byAngle: 0.2, duration: 0.5),
                .rotate(byAngle: -0.2, duration: 0.5)
            ]))
        ),
        "manager_human": Prop(
            emoji: "🧑‍💼", x: 0.5, y: 0.82,
            animation: .repeatForever(.sequence([
                .moveBy(x: 0, y: 5, duration: 0.6),
                .moveBy(x: 0, y: -5, duration: 0.6)
            ]))
        ),
        "memes_revive": Prop(
            emoji: "😂", x: 0.92, y: 0.8,
            animation: .repeatForever(.sequence([
                .scale(to: 1.2, duration: 0.5),
                .scale(to: 1.0, duration: 0.5)
            ]))
        ),
        "ficus_reborn": Prop(
            emoji: "🌱", x: 0.3, y: 0.12,
            animation: .repeatForever(.sequence([
                .scale(to: 1.1, duration: 1.2),
                .scale(to: 1.0, duration: 1.2)
            ]))
        )
    ]

    override init(size: CGSize = CGSize(width: 390, height: 260)) {
        super.init(size: size)
        scaleMode = .resizeFill
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(stage: OfficeStage, eventIDs: [String]) {
        guard stage != self.stage || eventIDs != self.eventIDs else { return }
        self.stage = stage
        self.eventIDs = eventIDs
        rebuild()
    }

    override func didMove(to view: SKView) {
        rebuild()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        // Positions are relative to the scene size; re-place everything
        // when resizeFill adapts the scene to the view.
        guard size != oldSize, size.width > 0 else { return }
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

        // Persistent props for every event that has fired, in trigger order.
        for id in eventIDs {
            guard let prop = Self.props[id] else { continue }
            let label = SKLabelNode(text: prop.emoji)
            label.fontSize = 32
            label.position = CGPoint(x: size.width * prop.x, y: size.height * prop.y)
            if let animation = prop.animation {
                label.run(animation)
            }
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
