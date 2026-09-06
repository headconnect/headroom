// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "UsageWidget",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "UsageWidgetCore"),
        .executableTarget(name: "UsageWidget", dependencies: ["UsageWidgetCore"]),
        // Checks run via `swift run`; XCTest and Swift Testing need Xcode, which
        // the Command Line Tools alone do not provide.
        .executableTarget(name: "UsageWidgetChecks", dependencies: ["UsageWidgetCore"]),
    ]
)
