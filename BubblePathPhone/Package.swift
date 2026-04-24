// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "BubblePathPhone",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .executable(name: "BubblePathPhone", targets: ["BubblePathPhone"])
    ],
    targets: [
        .executableTarget(
            name: "BubblePathPhone",
            path: "Sources"
        )
    ]
)
