// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "RulerApp",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "RulerApp",
            path: "Sources/RulerApp"
        )
    ]
)
