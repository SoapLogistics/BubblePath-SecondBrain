// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "BubblePathMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "BubblePathMac", targets: ["BubblePathMac"])
    ],
    targets: [
        .executableTarget(
            name: "BubblePathMac",
            path: "Sources"
        )
    ]
)
