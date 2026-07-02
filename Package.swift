// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "FootballMenuBar",
    platforms: [
        .macOS(.v13) // MenuBarExtra requires macOS 13+
    ],
    targets: [
        .executableTarget(
            name: "FootballMenuBar",
            path: "Sources/FootballMenuBar"
        )
    ]
)
