// swift-tools-version: 6.0
import PackageDescription
let appStore = Context.environment["PULSEBAR_DISTRIBUTION"] == "app-store"

let package = Package(
    name: "PulseBar",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "PulseBar", targets: ["PulseBar"]),
        .executable(name: "PulseBarHelper", targets: ["PulseBarHelper"]),
        .executable(name: "PulseBarHelperService", targets: ["PulseBarHelperService"])
    ],
    targets: [
        // Official SwiftPM artifact and checksum from Sparkle 2.10.0's manifest.
        .binaryTarget(
            name: "Sparkle",
            url: "https://github.com/sparkle-project/Sparkle/releases/download/2.10.0/Sparkle-for-Swift-Package-Manager.zip",
            checksum: "17e28312b8e18ab7cdbbe09a6fb28cc55a5479ec6c371dbc07cdecd2a14fd959"
        ),
        .target(name: "TemperatureSMC", linkerSettings: [.linkedFramework("IOKit")]),
        .target(name: "SpeedCore", resources: [.process("Resources")]),
        .target(name: "HardwareReaders", dependencies: ["SpeedCore", "TemperatureSMC"]),
        .target(name: "HelperIPC", dependencies: ["SpeedCore"]),
        .executableTarget(name: "PulseBarHelper", dependencies: ["HelperIPC", "SpeedCore"]),
        .executableTarget(name: "PulseBarHelperService", dependencies: ["HelperIPC", "HardwareReaders", "SpeedCore"]),
        .executableTarget(
            name: "PulseBar",
            dependencies: appStore ? ["SpeedCore", "HelperIPC"] : ["SpeedCore", "HardwareReaders", "Sparkle"],
            swiftSettings: appStore ? [.define("APP_STORE")] : [],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(name: "SpeedCoreTests", dependencies: ["SpeedCore", "HardwareReaders", "HelperIPC"])
    ],
    swiftLanguageModes: [.v5]
)
