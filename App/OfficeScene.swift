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
    private var daylight: SKSpriteNode?
    private var daylightProgress: Double = 0
    /// Deterministic counter to vary emotes and paper spawn points.
    private var tick = 0

    private struct Placement {
        let sprite: String
        /// Relative position in the scene (0...1).
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        var z: CGFloat = 1
        var animation: SKAction? = nil
        var isCast: Bool = false
        /// Floor items anchor at their feet so depth scaling keeps them
        /// standing on the ground; furniture/wall items stay centered.
        var onFloor: Bool = false
    }

    private static let bob: SKAction = .repeatForever(.sequence([
        .moveBy(x: 0, y: 6, duration: 0.5),
        .moveBy(x: 0, y: -6, duration: 0.5)
    ]))

    private static let float: SKAction = .repeatForever(.sequence([
        .moveBy(x: 0, y: 8, duration: 1.2),
        .moveBy(x: 0, y: -8, duration: 1.2)
    ]))

    /// The vacuum roams the floor in a little loop, not just left-right.
    private static let patrol: SKAction = .repeatForever(.sequence([
        .moveBy(x: 60, y: 14, duration: 2.2),
        .scaleX(to: -1, duration: 0.15),
        .moveBy(x: -35, y: 10, duration: 1.4),
        .moveBy(x: -25, y: -24, duration: 1.6),
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

    /// Squash-and-stretch on the cast when a task resolves. Preserves the
    /// horizontal flip of anyone currently walking the other way.
    func react() {
        for node in castNodes {
            let sign: CGFloat = node.xScale < 0 ? -1 : 1
            node.run(.sequence([
                .group([.scaleX(to: 1.25 * sign, duration: 0.08), .scaleY(to: 0.75, duration: 0.08)]),
                .group([.scaleX(to: 0.9 * sign, duration: 0.1), .scaleY(to: 1.15, duration: 0.1)]),
                .group([.scaleX(to: 1.0 * sign, duration: 0.12), .scaleY(to: 1.0, duration: 0.12)])
            ]))
        }
    }

    /// Emotes pop above the cast's heads when the player picks a side.
    func emote(for choice: WorkChoice) {
        let symbols = choice == .human ? ["❤️", "😄", "💪", "🍕"] : ["⚡️", "😨", "📉", "🫠"]
        for (index, member) in castNodes.enumerated() where index < 2 {
            let label = SKLabelNode(text: symbols[(tick + index) % symbols.count])
            label.fontSize = 24
            label.position = CGPoint(
                x: member.position.x,
                y: member.position.y + member.frame.height + 10
            )
            label.zPosition = 8
            addChild(label)
            label.run(.sequence([
                .wait(forDuration: 0.12 * Double(index)),
                .group([
                    .moveBy(x: 0, y: 26, duration: 0.7),
                    .sequence([.wait(forDuration: 0.45), .fadeOut(withDuration: 0.25)])
                ]),
                .removeFromParent()
            ]))
        }
        tick += 1
    }

    /// Warms the light as the workday progresses (0 = morning, 1 = sunset).
    func setDaylight(progress: Double) {
        daylightProgress = progress
        daylight?.color = SKColor(red: 0.95, green: 0.45, blue: 0.15, alpha: 1)
        daylight?.alpha = 0.22 * progress
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
        addDaylight()
        startPaperDrift()

        for placement in composition() {
            let texture = SKTexture(imageNamed: placement.sprite)
            texture.filteringMode = .nearest
            let node = SKSpriteNode(texture: texture)
            node.size = CGSize(width: placement.size, height: placement.size)
            if placement.onFloor {
                node.anchorPoint = CGPoint(x: 0.5, y: 0)
                // Lower on screen = closer to the camera.
                node.zPosition = 3 - placement.y * 4
            } else {
                node.zPosition = placement.z
            }
            node.position = CGPoint(x: size.width * placement.x, y: size.height * placement.y)
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
        // Staggered depth: back row by the desks (higher, smaller), front
        // row on the rug (lower, bigger). Bobs are desynced, and whoever
        // holds the second spot strolls around a bit.
        let spots: [(x: CGFloat, y: CGFloat, size: CGFloat)] = [
            (0.13, 0.24, 69),
            (0.34, 0.06, 93),
            (0.58, 0.15, 81)
        ]
        for (index, sprite) in cast.enumerated() {
            let spot = spots[index % spots.count]
            let idle: SKAction = .sequence([
                .wait(forDuration: 0.18 * Double(index)),
                .repeatForever(.sequence([
                    .moveBy(x: 0, y: 5, duration: 0.42 + 0.07 * Double(index)),
                    .moveBy(x: 0, y: -5, duration: 0.42 + 0.07 * Double(index))
                ]))
            ])
            // Everyone wanders, each with their own route and pace.
            let routes: [SKAction] = [
                .repeatForever(.sequence([
                    .wait(forDuration: 4.5),
                    .moveBy(x: 28, y: 0, duration: 1.8),
                    .wait(forDuration: 2.0),
                    .scaleX(to: -1, duration: 0.12),
                    .moveBy(x: -28, y: 0, duration: 1.8),
                    .scaleX(to: 1, duration: 0.12)
                ])),
                .repeatForever(.sequence([
                    .wait(forDuration: 2.5),
                    .scaleX(to: -1, duration: 0.12),
                    .moveBy(x: -50, y: 0, duration: 2.2),
                    .wait(forDuration: 1.2),
                    .scaleX(to: 1, duration: 0.12),
                    .moveBy(x: 50, y: 0, duration: 2.2)
                ])),
                .repeatForever(.sequence([
                    .wait(forDuration: 3.4),
                    .moveBy(x: 34, y: -8, duration: 2.0),
                    .wait(forDuration: 2.6),
                    .scaleX(to: -1, duration: 0.12),
                    .moveBy(x: -34, y: 8, duration: 2.0),
                    .scaleX(to: 1, duration: 0.12),
                    .wait(forDuration: 1.0)
                ]))
            ]
            let animation: SKAction = .group([idle, routes[index % routes.count]])
            items.append(Placement(
                sprite: sprite, x: spot.x, y: spot.y, size: spot.size,
                animation: animation, isCast: true, onFloor: true
            ))
        }

        // --- Fixtures: the ficus is one pot whose state follows events.
        let ficus = active.contains("plant_funeral") ? "ficus_wilted"
            : active.contains("ficus_reborn") ? "ficus_sprout"
            : "ficus_healthy"
        items.append(Placement(sprite: ficus, x: 0.78, y: 0.08, size: 50, onFloor: true))
        items.append(Placement(sprite: "printer", x: 0.90, y: 0.15, size: 48))
        if stage == .lively {
            items.append(Placement(sprite: "pizza_box", x: 0.60, y: 0.36, size: 34, z: 0.6))
        }
        if stage == .automated {
            items.append(Placement(sprite: "drone", x: 0.62, y: 0.55, size: 38, animation: Self.float.copy() as? SKAction))
        }

        // --- Event props, each in its own curated spot.
        if active.contains("robot_cleaner") {
            items.append(Placement(sprite: "robot_cleaner", x: 0.22, y: 0.01, size: 38, animation: Self.patrol.copy() as? SKAction, onFloor: true))
        }
        if active.contains("layoff_gino") {
            items.append(Placement(sprite: "mug_gino", x: 0.58, y: 0.16, size: 28, animation: .repeatForever(.sequence([
                .fadeAlpha(to: 0.55, duration: 1.5),
                .fadeAlpha(to: 1.0, duration: 1.5)
            ])), onFloor: true))
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

    private func addDaylight() {
        let overlay = SKSpriteNode(color: .clear, size: size)
        overlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.zPosition = 7
        overlay.blendMode = .alpha
        addChild(overlay)
        daylight = overlay
        setDaylight(progress: daylightProgress)
    }

    /// Every few seconds a sheet of paper flutters down near the desks.
    private func startPaperDrift() {
        removeAction(forKey: "papers")
        run(.repeatForever(.sequence([
            .wait(forDuration: 6),
            .run { [weak self] in self?.dropPaper() }
        ])), withKey: "papers")
    }

    private func dropPaper() {
        tick += 1
        let paper = SKLabelNode(text: "📄")
        paper.fontSize = 14
        let x = size.width * (0.2 + 0.15 * CGFloat(tick % 5))
        paper.position = CGPoint(x: x, y: size.height * 0.5)
        paper.zPosition = 4
        addChild(paper)
        paper.run(.sequence([
            .group([
                .moveBy(x: 0, y: -size.height * 0.34, duration: 2.6),
                .repeat(.sequence([
                    .moveBy(x: 12, y: 0, duration: 0.65),
                    .moveBy(x: -12, y: 0, duration: 0.65)
                ]), count: 2),
                .rotate(byAngle: 0.5, duration: 2.6)
            ]),
            .fadeOut(withDuration: 0.4),
            .removeFromParent()
        ]))
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
