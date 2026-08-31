// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "Flip7Core",
  platforms: [
    .iOS(.v18),
    .macOS(.v15),
  ],
  products: [
    .library(name: "Flip7Core", targets: ["Flip7Core"])
  ],
  targets: [
    .target(
      name: "Flip7Core",
      path: "flip7/Core"
    ),
    .target(
      name: "Flip7Session",
      dependencies: ["Flip7Core"],
      path: "flip7",
      exclude: [
        "Assets.xcassets",
        "Core",
        "ContentView.swift",
        "GameTableView.swift",
        "flip7App.swift",
      ],
      sources: [
        "GamePresentation.swift",
        "GameSession.swift",
      ]
    ),
    .testTarget(
      name: "Flip7CoreTests",
      dependencies: ["Flip7Core"],
      path: "Tests/Flip7CoreTests"
    ),
    .testTarget(
      name: "Flip7SessionTests",
      dependencies: ["Flip7Core", "Flip7Session"],
      path: "Tests/Flip7SessionTests"
    ),
  ]
)
