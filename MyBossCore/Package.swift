// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MyBossCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MyBossCore", targets: ["MyBossCore"])
    ],
    targets: [
        .target(name: "MyBossCore", resources: [.process("Resources")]),
        .testTarget(name: "MyBossCoreTests", dependencies: ["MyBossCore"])
    ]
)
