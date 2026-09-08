// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "rations",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "RationsCore"),
        .executableTarget(name: "rations", dependencies: ["RationsCore"]),
        // Checks run via `swift run`; XCTest and Swift Testing need Xcode, which
        // the Command Line Tools alone do not provide.
        .executableTarget(name: "RationsChecks", dependencies: ["RationsCore"]),
    ]
)
