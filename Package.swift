// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodexPeek",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "CodexPeekCore", targets: ["CodexPeekCore"]),
        .executable(name: "CodexPeek", targets: ["CodexPeekApp"]),
        .executable(name: "CodexPeekChecks", targets: ["CodexPeekChecks"])
    ],
    targets: [
        .target(name: "CodexPeekCore"),
        .executableTarget(name: "CodexPeekApp", dependencies: ["CodexPeekCore"]),
        .executableTarget(name: "CodexPeekChecks", dependencies: ["CodexPeekCore"], path: "Tests/CodexPeekCoreTests")
    ],
    swiftLanguageModes: [.v5]
)
