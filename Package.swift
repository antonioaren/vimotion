// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "vimotion",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "vimotion",
            path: "Sources/vimotion"
        ),
        .testTarget(
            name: "vimotionTests",
            dependencies: ["vimotion"],
            path: "Tests/vimotionTests"
        )
    ]
)
