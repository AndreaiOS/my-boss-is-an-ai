import SpriteKit
import MyBossCore

/// The office. Composition is semantic: the cast and fixtures react to the
/// stage and to which events are active. Characters walk with real frame
/// animation (sliced from the batch-3 sheets) and react to choices with
/// dedicated poses. Updated only at day boundaries.
final class OfficeScene: SKScene {

    private var stage: OfficeStage = .lively
    private var eventIDs: [String] = []
    private var cast: [CastMember] = []
    private var daylight: SKSpriteNode?
    private var daylightProgress: Double = 0
    /// Deterministic counter to vary emotes and paper spawn points.
    private var tick = 0

    private struct CastMember {
        let node: SKSpriteNode
        let standing: SKTexture
        /// [celebrating, shocked], if this character has reaction art.
        let reactions: [SKTexture]?
    }

    private struct Placement {
        let sprite: String
        /// Relative position in the scene (0...1).
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        var z: CGFloat = 1
        var animation: SKAction? = nil
        /// Floor items anchor at their feet so depth scaling keeps them
        /// standing on the ground; furniture/wall items stay centered.
        var onFloor: Bool = false
        var isCast: Bool = false
    }

    private static let walkSheets: [String: String] = [
        "worker_a": "walk_worker_a",
        "worker_b": "walk_worker_b",
        "gino": "walk_gino",
        "robot_worker": "walk_robot"
    ]

    private static let reactSheets: [String: String] = [
        "worker_a": "react_worker_a",
        "worker_b": "react_worker_b",
        "gino": "react_gino"
    ]

    private static let bob: SKAction = .repeatForever(.sequence([
        .moveBy(x: 0, y: 5, duration: 0.5),
        .moveBy(x: 0, y: -5, duration: 0.5)
    ]))

    private static let float: SKAction = .repeatForever(.sequence([
        .moveBy(x: 0, y: 8, duration: 1.2),
        .moveBy(x: 0, y: -8, duration: 1.2)
    ]))

    /// The vacuum roams the floor in a little loop, not just left-right.
    private static let patrol: SKAction = .repeatForever(.sequence([
        .moveBy(x: 70, y: 16, duration: 2.2),
        .scaleX(to: -1, duration: 0.15),
        .moveBy(x: -40, y: 12, duration: 1.4),
        .moveBy(x: -30, y: -28, duration: 1.6),
        .scaleX(to: 1, duration: 0.15)
    ]))

    override init(size: CGSize = CGSize(width: 390, height: 470)) {
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

    /// Squash-and-stretch plus the reaction pose when a task resolves.
    func react(to choice: WorkChoice) {
        for member in cast {
            let sign: CGFloat = member.node.xScale < 0 ? -1 : 1
            member.node.run(.sequence([
                .group([.scaleX(to: 1.25 * sign, duration: 0.08), .scaleY(to: 0.75, duration: 0.08)]),
                .group([.scaleX(to: 0.9 * sign, duration: 0.1), .scaleY(to: 1.15, duration: 0.1)]),
                .group([.scaleX(to: 1.0 * sign, duration: 0.12), .scaleY(to: 1.0, duration: 0.12)])
            ]))
            if let reactions = member.reactions {
                member.node.run(.sequence([
                    .setTexture(reactions[choice == .human ? 0 : 1]),
                    .wait(forDuration: 0.9),
                    .setTexture(member.standing)
                ]))
            }
        }
    }

    /// Emotes pop above the cast's heads when the player picks a side.
    func emote(for choice: WorkChoice) {
        let symbols = choice == .human ? ["❤️", "😄", "💪", "🍕"] : ["⚡️", "😨", "📉", "🫠"]
        for (index, member) in cast.enumerated() where index < 2 {
            let label = SKLabelNode(text: symbols[(tick + index) % symbols.count])
            label.fontSize = 24
            label.position = CGPoint(
                x: member.node.position.x,
                y: member.node.position.y + member.node.frame.height + 10
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

    // MARK: - Tap to examine

    /// One-liners shown when the player pokes things, Monkey Island style.
    private static let examineLines: [String: [String]] = [
        "worker_a": ["\"I'm fine. This is my third coffee. I'm fine.\"", "\"Have you tried turning HR off and on again?\""],
        "worker_b": ["\"I'm updating my LinkedIn. Just in case.\"", "\"This laptop has seen things.\""],
        "gino": ["\"Twenty-two years here. The mug was a gift from the '09 audit.\"", "\"You touch the mug, we have a problem.\""],
        "robot_worker": ["\"PERFORMING TEAMWORK. MORALE AT ACCEPTABLE LEVELS.\"", "{\"smalltalk\": \"weather\", \"status\": \"delightful\"}"],
        "karen": ["\"I laminated the birthday calendar. ALL the birthdays.\"", "\"My cat could do your boss's job. Politely.\""],
        "intern": ["\"Video 61 of 74. Send help. Or coffee.\"", "\"Is... is the mug load-bearing?\""],
        "ficus_healthy": ["The ficus thrives. It has heard every secret in this office.", "It leans toward you. It missed you."],
        "ficus_wilted": ["It's not dead. It's 'pivoting to dormancy'.", "A single leaf falls. Somewhere, a drone logs it."],
        "ficus_sprout": ["A tiny sprout. Hope, in vase form.", "Someone has been talking to it at night. HR knows who."],
        "printer": ["It fears no jam. It fears obsolescence.", "PC LOAD LETTER. It refuses to elaborate."],
        "pizza_box": ["Cold. Sacred. Communal.", "The last slice has been under negotiation since Tuesday."],
        "robot_cleaner": ["It judges your crumbs. Silently. At 60 decibels.", "It has mapped the office. And your weaknesses."],
        "mug_gino": ["Gino's mug. Nobody touches it. Nobody ever will.", "It still smells faintly of the '09 audit."],
        "coffee_machine_ai": ["\"YOUR USUAL, VALUED RESOURCE #4?\"", "It spells your name right. Every time. Unsettling."],
        "barista": ["\"One 'Andrra'? 'Andrae'? Whatever, it's yours.\"", "\"The machine never asked about your weekend. I do.\""],
        "manager_chart": ["Your manager. Currently 34% 'synergy', 66% 'concern'.", "It scheduled a 1:1 with itself. It went poorly."],
        "manager_human": ["\"Let's put a pin in that and circle back.\"", "\"My door is always open. That's why I'm cold.\""],
        "kpi_dashboard": ["The memes are gone. The KPIs remain. Forever.", "Engagement: up. Joy: not found (404)."],
        "meme_wall": ["Today's entry: a cat in a tie. Masterpiece.", "Productivity -12%. Morale +200%. Net positive."],
        "drone": ["It waters plants and judges you. Multitasking.", "It attended the ficus funeral. Late. With confetti. Wrong event."]
    ]

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let tapped = nodes(at: location)
            .compactMap { node -> (SKNode, String)? in
                guard let name = node.name, Self.examineLines[name] != nil else { return nil }
                return (node, name)
            }
            .max { $0.0.zPosition < $1.0.zPosition }
        guard let (node, name) = tapped, let lines = Self.examineLines[name] else { return }
        tick += 1
        showBubble(lines[tick % lines.count], above: node)
    }

    private func showBubble(_ text: String, above node: SKNode) {
        childNode(withName: "examine_bubble")?.removeFromParent()

        let label = SKLabelNode(text: text)
        label.fontName = "Menlo-Bold"
        label.fontSize = 11
        label.fontColor = SKColor(red: 0.07, green: 0.05, blue: 0.04, alpha: 1)
        label.numberOfLines = 0
        label.preferredMaxLayoutWidth = size.width * 0.62
        label.verticalAlignmentMode = .center

        let padding: CGFloat = 10
        let background = SKShapeNode(
            rect: label.frame.insetBy(dx: -padding, dy: -padding),
            cornerRadius: 4
        )
        background.fillColor = SKColor(red: 0.96, green: 0.90, blue: 0.78, alpha: 0.97)
        background.strokeColor = SKColor(red: 0.07, green: 0.05, blue: 0.04, alpha: 1)
        background.lineWidth = 2

        let bubble = SKNode()
        bubble.name = "examine_bubble"
        bubble.addChild(background)
        bubble.addChild(label)
        bubble.zPosition = 9

        let width = background.frame.width
        let x = min(max(node.position.x, width / 2 + 6), size.width - width / 2 - 6)
        let y = min(node.position.y + node.frame.height + 26, size.height - 40)
        bubble.position = CGPoint(x: x, y: y)
        bubble.setScale(0.6)
        addChild(bubble)
        bubble.run(.sequence([
            .scale(to: 1.0, duration: 0.12),
            .wait(forDuration: 2.6),
            .fadeOut(withDuration: 0.3),
            .removeFromParent()
        ]))
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

    // MARK: - Build

    private func rebuild() {
        removeAllChildren()
        cast = []
        addBackground()
        addDaylight()
        startPaperDrift()

        for placement in composition() {
            let texture = SKTexture(imageNamed: placement.sprite)
            texture.filteringMode = .nearest
            let node = SKSpriteNode(texture: texture)
            node.name = placement.sprite
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
            if placement.isCast {
                let index = cast.count
                let idle = SKAction.sequence([
                    .wait(forDuration: 0.18 * Double(index)),
                    .repeatForever(.sequence([
                        .moveBy(x: 0, y: 5, duration: 0.42 + 0.07 * Double(index)),
                        .moveBy(x: 0, y: -5, duration: 0.42 + 0.07 * Double(index))
                    ]))
                ])
                let walkFrames = Self.walkSheets[placement.sprite].map { frames(fromSheet: $0, count: 3) }
                let reactions = Self.reactSheets[placement.sprite].map { frames(fromSheet: $0, count: 2) }
                node.run(.group([idle, route(index: index, walkFrames: walkFrames)]))
                cast.append(CastMember(node: node, standing: texture, reactions: reactions))
            }
            addChild(node)
        }
    }

    /// Slices a horizontal sprite sheet into equal square frames.
    private func frames(fromSheet name: String, count: Int) -> [SKTexture] {
        let sheet = SKTexture(imageNamed: name)
        sheet.filteringMode = .nearest
        return (0..<count).map { index in
            let frame = SKTexture(
                rect: CGRect(x: CGFloat(index) / CGFloat(count), y: 0, width: 1 / CGFloat(count), height: 1),
                in: sheet
            )
            frame.filteringMode = .nearest
            return frame
        }
    }

    /// A wander route where every move segment plays the walk cycle.
    private func route(index: Int, walkFrames: [SKTexture]?) -> SKAction {
        func step(_ dx: CGFloat, _ dy: CGFloat, _ duration: TimeInterval) -> SKAction {
            let move = SKAction.moveBy(x: dx, y: dy, duration: duration)
            guard let walkFrames else { return move }
            let cycle = SKAction.animate(with: walkFrames, timePerFrame: 0.13, resize: false, restore: true)
            let cycles = max(1, Int(duration / (0.13 * Double(walkFrames.count))))
            return .group([move, .repeat(cycle, count: cycles)])
        }
        switch index % 3 {
        case 0:
            return .repeatForever(.sequence([
                .wait(forDuration: 4.5),
                step(30, 0, 1.8),
                .wait(forDuration: 2.0),
                .scaleX(to: -1, duration: 0.12),
                step(-30, 0, 1.8),
                .scaleX(to: 1, duration: 0.12)
            ]))
        case 1:
            return .repeatForever(.sequence([
                .wait(forDuration: 2.5),
                .scaleX(to: -1, duration: 0.12),
                step(-56, 0, 2.2),
                .wait(forDuration: 1.2),
                .scaleX(to: 1, duration: 0.12),
                step(56, 0, 2.2)
            ]))
        default:
            return .repeatForever(.sequence([
                .wait(forDuration: 3.4),
                step(38, -10, 2.0),
                .wait(forDuration: 2.6),
                .scaleX(to: -1, duration: 0.12),
                step(-38, 10, 2.0),
                .scaleX(to: 1, duration: 0.12),
                .wait(forDuration: 1.0)
            ]))
        }
    }

    private func composition() -> [Placement] {
        let active = Set(eventIDs)
        var items: [Placement] = []

        // --- Floor cast on the free corridor: back, front, mid.
        var members: [String] = switch stage {
        case .lively: ["worker_a", "worker_b", "gino"]
        case .hybrid: ["worker_a", "robot_worker", "gino"]
        case .automated: ["robot_worker", "robot_worker", "robot_worker"]
        }
        if active.contains("layoff_gino") {
            members.removeAll { $0 == "gino" }
        }
        if active.contains("coworkers_bots") {
            members = members.map { $0.hasPrefix("worker") ? "robot_worker" : $0 }
        }
        let spots: [(x: CGFloat, y: CGFloat, size: CGFloat)] = [
            (0.18, 0.40, 62),
            (0.38, 0.22, 94),
            (0.62, 0.30, 78)
        ]
        for (index, sprite) in members.enumerated() {
            let spot = spots[index % spots.count]
            items.append(Placement(
                sprite: sprite, x: spot.x, y: spot.y, size: spot.size,
                onFloor: true, isCast: true
            ))
        }

        // Guest desk worker: Karen keeps the lively office company, the
        // intern survives the hybrid one.
        if stage == .lively {
            items.append(Placement(sprite: "karen", x: 0.12, y: 0.24, size: 88, animation: Self.bob.copy() as? SKAction, onFloor: true))
        }
        if stage == .hybrid {
            items.append(Placement(sprite: "intern", x: 0.12, y: 0.24, size: 88, animation: Self.bob.copy() as? SKAction, onFloor: true))
        }

        // --- Fixtures: the ficus is one pot whose state follows events.
        let ficus = active.contains("plant_funeral") ? "ficus_wilted"
            : active.contains("ficus_reborn") ? "ficus_sprout"
            : "ficus_healthy"
        items.append(Placement(sprite: ficus, x: 0.72, y: 0.11, size: 84, onFloor: true))
        items.append(Placement(sprite: "printer", x: 0.92, y: 0.11, size: 70, onFloor: true))
        if stage == .automated {
            items.append(Placement(sprite: "drone", x: 0.50, y: 0.46, size: 50, animation: Self.float.copy() as? SKAction))
        }

        // --- Event props, each in its own curated spot.
        if active.contains("robot_cleaner") {
            items.append(Placement(sprite: "robot_cleaner", x: 0.16, y: 0.19, size: 46, animation: Self.patrol.copy() as? SKAction, onFloor: true))
        }
        if active.contains("layoff_gino") {
            items.append(Placement(sprite: "mug_gino", x: 0.51, y: 0.12, size: 40, animation: .repeatForever(.sequence([
                .fadeAlpha(to: 0.55, duration: 1.5),
                .fadeAlpha(to: 1.0, duration: 1.5)
            ])), onFloor: true))
        }
        let coffeeSpot: (x: CGFloat, y: CGFloat, onFloor: Bool) = stage == .automated
            ? (0.07, 0.11, true)
            : (0.90, 0.42, false)
        if active.contains("ai_coffee_machine") {
            items.append(Placement(sprite: "coffee_machine_ai", x: coffeeSpot.x, y: coffeeSpot.y, size: 60, z: 0.6, animation: .repeatForever(.sequence([
                .scale(to: 1.1, duration: 0.4),
                .scale(to: 1.0, duration: 0.4),
                .wait(forDuration: 2)
            ])), onFloor: coffeeSpot.onFloor))
        }
        if active.contains("barista_returns") {
            items.append(Placement(sprite: "barista", x: coffeeSpot.x, y: coffeeSpot.y, size: 66, z: 0.6, animation: Self.bob.copy() as? SKAction, onFloor: coffeeSpot.onFloor))
        }
        if active.contains("manager_algorithm") {
            items.append(Placement(sprite: "manager_chart", x: 0.14, y: 0.54, size: 56, z: 0.5, animation: Self.float.copy() as? SKAction))
        }
        if active.contains("manager_human") {
            items.append(Placement(sprite: "manager_human", x: 0.14, y: 0.54, size: 64, z: 0.5, animation: Self.bob.copy() as? SKAction))
        }
        if active.contains("memes_die") {
            items.append(Placement(sprite: "kpi_dashboard", x: 0.50, y: 0.72, size: 56, z: 0.5))
        }
        if active.contains("memes_revive") {
            items.append(Placement(sprite: "meme_wall", x: 0.50, y: 0.72, size: 56, z: 0.5, animation: .repeatForever(.sequence([
                .scale(to: 1.06, duration: 0.5),
                .scale(to: 1.0, duration: 0.5)
            ]))))
        }
        return items
    }

    // MARK: - Nodes

    private func addBackground() {
        let texture = SKTexture(imageNamed: "bg_\(stage.rawValue)_v2")
        texture.filteringMode = .nearest
        let node = SKSpriteNode(texture: texture)
        let scale = max(size.width / texture.size().width, size.height / texture.size().height)
        node.setScale(scale)
        // Anchor near the bottom, nudged down 10% so the counter's wooden
        // face doesn't eat the scene; the crop eats the ceiling instead.
        node.position = CGPoint(x: size.width / 2, y: texture.size().height * scale / 2 - size.height * 0.10)
        node.zPosition = -1
        addChild(node)
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
        paper.position = CGPoint(x: x, y: size.height * 0.46)
        paper.zPosition = 4
        addChild(paper)
        paper.run(.sequence([
            .group([
                .moveBy(x: 0, y: -size.height * 0.20, duration: 2.6),
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
}
