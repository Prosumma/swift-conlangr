// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "Conlangr",
  platforms: [.macOS(.v13), .iOS(.v16), .watchOS(.v9), .tvOS(.v16)],
  products: [
    .library(
      name: "Conlangr",
      targets: ["Conlangr"]
    ),
    .executable(
      name: "conlangr",
      targets: ["ConlangrCLI"]
    ),
  ],
  dependencies: [
    .package(
      url: "https://github.com/Prosumma/Parsimonious",
      from: "3.1.0"
    ),
    .package(
      url: "https://github.com/apple/swift-argument-parser",
      from: "1.7.0"
    ),
  ],
  targets: [
    .target(
      name: "Conlangr",
      dependencies: [
        .product(name: "Parsimonious", package: "Parsimonious")
      ]
    ),
    .executableTarget(
      name: "ConlangrCLI",
      dependencies: [
        "Conlangr",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]
    ),
    .testTarget(
        name: "ConlangrTests",
        dependencies: ["Conlangr"]
    ),
    .testTarget(
      name: "ConlangrCLITests",
      dependencies: ["ConlangrCLI"]
    ),
  ]
)
