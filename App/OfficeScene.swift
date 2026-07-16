import SpriteKit
import MyBossCore

/// The office, rendered with the batch-1 pixel-art assets. The background
/// swaps with the stage; stage decorations and event props are sprites
/// (with an emoji fallback for content that has no art yet).
final class OfficeScene: SKScene {

    private var stage: OfficeStage = .lively
    private var eventIDs: [String] = []

    private enum Visual {
        case sprite(String)
        case emoji(String)
    }

    /// How a triggered office event shows up in the scene, permanently.
    private struct Prop {
        let visual: Visual
        /// Relative position in the scene (0...1).
        let x: CGFloat
        let y: CGFloat
        let animation: SKAction?
    }

    private static let bob: SKAction = .repeatForever(.sequence([
        .moveBy(x: 0, y: 6, duration: 0.5),
        .moveBy(x: 0, y: -6, duration: 0.5)
    ]))

    private static let props: [String: Prop] = [
        "robot_cleaner": Prop(
            visual: .sprite("robot_cleaner"), x: 0.15, y: 0.12,
            animation: .repeatForever(.sequence([
                .moveBy(x: 60, y: 0, duration: 2.5),
                .scaleX(to: -1, duration: 0.15),
                .moveBy(x: -60, y: 0, duration: 2.5),
                .scaleX(to: 1, duration: 0.15)
            ]))
        ),
        "layoff_gino": Prop(
            visual: .sprite("mug_gino"), x: 0.85, y: 0.14,
            animation: .repeatForever(.sequence([
                .fadeAlpha(to: 0.55, duration: 1.5),
                .fadeAlpha(to: 1.0, duration: 1.5)
            ]))
        ),
        "gino_rehired": Prop(
            visual: .sprite("gino"), x: 0.85, y: 0.16,
            animation: .repeatForever(.sequence([
                .moveBy(x: 0, y: 10, duration: 0.25),
                .moveBy(x: 0, y: -10, duration: 0.25),
                .wait(forDuration: 1.5)
            ]))
        ),
        "ai_coffee_machine": Prop(
            visual: .sprite("coffee_machine_ai"), x: 0.07, y: 0.42,
            animation: .repeatForever(.sequence([
                .scale(to: 1.12, duration: 0.4),
                .scale(to: 1.0, duration: 0.4),
                .wait(forDuration: 2)
            ]))
        ),
        "barista_returns": Prop(
            visual: .sprite("barista"), x: 0.07, y: 0.42,
            animation: bob
        ),
        "manager_algorithm": Prop(
            visual: .sprite("manager_chart"), x: 0.5, y: 0.72,
            animation: .repeatForever(.sequence([
                .moveBy(x: 0, y: 8, duration: 1.2),
                .moveBy(x: 0, y: -8, duration: 1.2)
            ]))
        ),
        "manager_human": Prop(
            visual: .sprite("manager_human"), x: 0.5, y: 0.72,
            animation: bob
        ),
        "coworkers_bots": Prop(
            visual: .sprite("robot_worker"), x: 0.65, y: 0.14,
            animation: nil
        ),
        "memes_die": Prop(
            visual: .sprite("kpi_dashboard"), x: 0.92, y: 0.75,
            animation: nil
        ),
        "memes_revive": Prop(
            visual: .sprite("meme_wall"), x: 0.92, y: 0.75,
            animation: .repeatForever(.sequence([
                .scale(to: 1.08, duration: 0.5),
                .scale(to: 1.0, duration: 0.5)
            ]))
        ),
        "plant_funeral": Prop(
            visual: .sprite("ficus_wilted"), x: 0.3, y: 0.14,
            animation: .repeatForever(.sequence([
                .rotate(byAngle: -0.1, duration: 2),
                .rotate(byAngle: 0.1, duration: 2)
            ]))
        ),
        "ficus_reborn": Prop(
            visual: .sprite("ficus_sprout"), x: 0.3, y: 0.14,
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

    private var decorationNodes: [SKNode] = []

    /// Squash-and-stretch on everyone in the office when a task resolves.
    func react() {
        for node in decorationNodes {
            node.run(.sequence([
                .group([.scaleX(to: 1.25, duration: 0.08), .scaleY(to: 0.75, duration: 0.08)]),
                .group([.scaleX(to: 0.9, duration: 0.1), .scaleY(to: 1.15, duration: 0.1)]),
                .group([.scaleX(to: 1.0, duration: 0.12), .scaleY(to: 1.0, duration: 0.12)])
            ]))
        }
    }

    /// Quick horizontal shake when an office event fires.
    func shake() {
        for child in children {
            child.run(.sequence([
                .moveBy(x: 6, y: 0, duration: 0.05),
                .moveBy(x: -12, y: 0, duration: 0.08),
                .moveBy(x: 6, y: 0, duration: 0.05)
            ]))
        }
    }

    private func rebuild() {
        removeAllChildren()
        decorationNodes = []
        addBackground()

        let cast = decorations(for: stage)
        for (index, spriteName) in cast.enumerated() {
            let node = makeNode(.sprite(spriteName))
            let step = 0.76 / CGFloat(max(cast.count - 1, 1))
            node.position = CGPoint(
                x: size.width * (0.12 + step * CGFloat(index)),
                y: size.height * 0.16
            )
            node.zPosition = 1
            node.run(Self.bob.copy() as! SKAction)
            addChild(node)
            decorationNodes.append(node)
        }

        // Persistent props for every event that has fired, in trigger order.
        for id in eventIDs {
            guard let prop = Self.props[id] else { continue }
            let node = makeNode(prop.visual)
            node.position = CGPoint(x: size.width * prop.x, y: size.height * prop.y)
            node.zPosition = 2
            if let animation = prop.animation {
                node.run(animation)
            }
            addChild(node)
        }
    }

    private func addBackground() {
        let texture = SKTexture(imageNamed: "bg_\(stage.rawValue)")
        let node = SKSpriteNode(texture: texture)
        let scale = max(size.width / texture.size().width, size.height / texture.size().height)
        node.setScale(scale)
        node.position = CGPoint(x: size.width / 2, y: size.height / 2)
        node.zPosition = -1
        addChild(node)
    }

    private func makeNode(_ visual: Visual) -> SKNode {
        switch visual {
        case .sprite(let name):
            let texture = SKTexture(imageNamed: name)
            texture.filteringMode = .nearest
            let node = SKSpriteNode(texture: texture)
            node.size = CGSize(width: 56, height: 56)
            return node
        case .emoji(let text):
            let label = SKLabelNode(text: text)
            label.fontSize = 32
            return label
        }
    }

    private func decorations(for stage: OfficeStage) -> [String] {
        switch stage {
        case .lively:
            ["worker_a", "worker_b", "gino", "ficus_healthy", "pizza_box", "printer"]
        case .hybrid:
            ["worker_a", "robot_worker", "gino", "ficus_healthy", "printer"]
        case .automated:
            ["robot_worker", "robot_worker", "drone", "coffee_machine_ai", "robot_cleaner"]
        }
    }
}
