// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LobbyOS",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.4.0")
    ],
    targets: [
        .target(
            name: "LobbyOS",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ]
        )
    ]
) 