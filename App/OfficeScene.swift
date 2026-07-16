import SpriteKit
import MyBossCore

/// The office. Composition is semantic: the cast and fixtures react to the
/// stage and to which events are active (Gino leaves when laid off and his
/// mug stays; the ficus is one pot whose state changes; the barista and the
/// AI coffee machine swap the same corner). Updated only at day boundaries.
final class OfficeScene: SKScene {

    private var stage: OfficeStage = .lively
    private var eventIDs: [String] = []
    private var castNodes: [SKNode] = []

    private struct Placement {
        let sprite: String
        /// Relative position in the scene (0...1).
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        var z: CGFloat = 1
        var animation: SKAction? = nil
        var isCast: Bool = false
    }

    private static let bob: SKAction = .repeatForever(.sequence([
        .moveBy(x: 0, y: 6, duration: 0.5),
        .moveBy(x: 0, y: -6, duration: 0.5)
    ]))

    private static let float: SKAction = .repeatForever(.sequence([
        .moveBy(x: 0, y: 8, duration: 1.2),
        .moveBy(x: 0, y: -8, duration: 1.2)
    ]))

    private static let patrol: SKAction = .repeatForever(.sequence([
        .moveBy(x: 70, y: 0, duration: 3),
        .scaleX(to: -1, duration: 0.15),
        .moveBy(x: -70, y: 0, duration: 3),
        .scaleX(to: 1, duration: 0.15)
    ]))

    override init(size: CGSize = CGSize(width: 390, height: 420)) {
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
        guard size != oldSize, size.width > 0 else { return }
        rebuild()
    }

    /// Squash-and-stretch on the cast when a task resolves.
    func react() {
        for node in castNodes {
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
        castNodes = []
        addBackground()

        for placement in composition() {
            let texture = SKTexture(imageNamed: placement.sprite)
            texture.filteringMode = .nearest
            let node = SKSpriteNode(texture: texture)
            node.size = CGSize(width: placement.size, height: placement.size)
            node.position = CGPoint(x: size.width * placement.x, y: size.height * placement.y)
            node.zPosition = placement.z
            if let animation = placement.animation {
                node.run(animation)
            }
            addChild(node)
            if placement.isCast {
                castNodes.append(node)
            }
        }
    }

    private func composition() -> [Placement] {
        let active = Set(eventIDs)
        var items: [Placement] = []

        // --- Floor cast: three slots, left to center.
        var cast: [String] = switch stage {
        case .lively: ["worker_a", "worker_b", "gino"]
        case .hybrid: ["worker_a", "robot_worker", "gino"]
        case .automated: ["robot_worker", "robot_worker", "robot_worker"]
        }
        if active.contains("layoff_gino") {
            cast.removeAll { $0 == "gino" }
        }
        if active.contains("coworkers_bots") {
            cast = cast.map { $0.hasPrefix("worker") ? "robot_worker" : $0 }
        }
        for (index, sprite) in cast.enumerated() {
            items.append(Placement(
                sprite: sprite, x: 0.14 + 0.20 * CGFloat(index), y: 0.15,
                size: 58, animation: Self.bob.copy() as? SKAction, isCast: true
            ))
        }

        // --- Fixtures: the ficus is one pot whose state follows events.
        let ficus = active.contains("plant_funeral") ? "ficus_wilted"
            : active.contains("ficus_reborn") ? "ficus_sprout"
            : "ficus_healthy"
        items.append(Placement(sprite: ficus, x: 0.74, y: 0.14, size: 46))
        items.append(Placement(sprite: "printer", x: 0.90, y: 0.15, size: 48))
        if stage == .lively {
            items.append(Placement(sprite: "pizza_box", x: 0.60, y: 0.36, size: 34, z: 0.6))
        }
        if stage == .automated {
            items.append(Placement(sprite: "drone", x: 0.62, y: 0.55, size: 38, animation: Self.float.copy() as? SKAction))
        }

        // --- Event props, each in its own curated spot.
        if active.contains("robot_cleaner") {
            items.append(Placement(sprite: "robot_cleaner", x: 0.22, y: 0.05, size: 38, z: 3, animation: Self.patrol.copy() as? SKAction))
        }
        if active.contains("layoff_gino") {
            items.append(Placement(sprite: "mug_gino", x: 0.54, y: 0.16, size: 30, animation: .repeatForever(.sequence([
                .fadeAlpha(to: 0.55, duration: 1.5),
                .fadeAlpha(to: 1.0, duration: 1.5)
            ]))))
        }
        if active.contains("ai_coffee_machine") {
            items.append(Placement(sprite: "coffee_machine_ai", x: 0.06, y: 0.42, size: 44, z: 0.6, animation: .repeatForever(.sequence([
                .scale(to: 1.1, duration: 0.4),
                .scale(to: 1.0, duration: 0.4),
                .wait(forDuration: 2)
            ]))))
        }
        if active.contains("barista_returns") {
            items.append(Placement(sprite: "barista", x: 0.06, y: 0.42, size: 50, z: 0.6, animation: Self.bob.copy() as? SKAction))
        }
        if active.contains("manager_algorithm") {
            items.append(Placement(sprite: "manager_chart", x: 0.50, y: 0.76, size: 44, z: 0.5, animation: Self.float.copy() as? SKAction))
        }
        if active.contains("manager_human") {
            items.append(Placement(sprite: "manager_human", x: 0.50, y: 0.76, size: 50, z: 0.5, animation: Self.bob.copy() as? SKAction))
        }
        if active.contains("memes_die") {
            items.append(Placement(sprite: "kpi_dashboard", x: 0.91, y: 0.74, size: 44, z: 0.5))
        }
        if active.contains("memes_revive") {
            items.append(Placement(sprite: "meme_wall", x: 0.91, y: 0.74, size: 44, z: 0.5, animation: .repeatForever(.sequence([
                .scale(to: 1.06, duration: 0.5),
                .scale(to: 1.0, duration: 0.5)
            ]))))
        }
        return items
    }

    private func addBackground() {
        let texture = SKTexture(imageNamed: "bg_\(stage.rawValue)")
        texture.filteringMode = .nearest
        let node = SKSpriteNode(texture: texture)
        let scale = max(size.width / texture.size().width, size.height / texture.size().height)
        node.setScale(scale)
        node.position = CGPoint(x: size.width / 2, y: size.height / 2)
        node.zPosition = -1
        addChild(node)
    }
}
