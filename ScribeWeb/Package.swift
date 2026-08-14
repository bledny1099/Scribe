// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ScribeWeb",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/twostraws/Ignite.git", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "ScribeWeb",
            dependencies: ["Ignite"]
        )
    ]
)
