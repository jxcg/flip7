// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Flip7Core",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "Flip7Core", targets: ["Flip7Core"]),
    ],
    targets: [
        .target(
            name: "Flip7Core",
            path: "flip7/Core"
        ),
        .testTarget(
            name: "Flip7CoreTests",
            dependencies: ["Flip7Core"],
            path: "Tests/Flip7CoreTests"
        ),
    ]
)
