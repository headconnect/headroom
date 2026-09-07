// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "range-anxiety",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "RangeAnxietyCore"),
        .executableTarget(name: "range-anxiety", dependencies: ["RangeAnxietyCore"]),
        // Checks run via `swift run`; XCTest and Swift Testing need Xcode, which
        // the Command Line Tools alone do not provide.
        .executableTarget(name: "RangeAnxietyChecks", dependencies: ["RangeAnxietyCore"]),
    ]
)
