// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "headroom",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "HeadroomCore"),
        .executableTarget(name: "headroom", dependencies: ["HeadroomCore"]),
        // Checks run via `swift run`; XCTest and Swift Testing need Xcode, which
        // the Command Line Tools alone do not provide.
        .executableTarget(name: "HeadroomChecks", dependencies: ["HeadroomCore"]),
    ]
)
