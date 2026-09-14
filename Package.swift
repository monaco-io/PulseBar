// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PulseBar",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "PulseBar", targets: ["PulseBar"])],
    targets: [
        .target(name: "SpeedCore", resources: [.process("Resources")]),
        .executableTarget(name: "PulseBar", dependencies: ["SpeedCore"]),
        .testTarget(name: "SpeedCoreTests", dependencies: ["SpeedCore"])
    ],
    swiftLanguageModes: [.v5]
)
