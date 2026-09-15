// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PulseBar",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "PulseBar", targets: ["PulseBar"])],
    targets: [
        // Official SwiftPM artifact and checksum from Sparkle 2.10.0's manifest.
        .binaryTarget(
            name: "Sparkle",
            url: "https://github.com/sparkle-project/Sparkle/releases/download/2.10.0/Sparkle-for-Swift-Package-Manager.zip",
            checksum: "17e28312b8e18ab7cdbbe09a6fb28cc55a5479ec6c371dbc07cdecd2a14fd959"
        ),
        .target(name: "SpeedCore", resources: [.process("Resources")]),
        .executableTarget(
            name: "PulseBar",
            dependencies: ["SpeedCore", "Sparkle"],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(name: "SpeedCoreTests", dependencies: ["SpeedCore"])
    ],
    swiftLanguageModes: [.v5]
)
