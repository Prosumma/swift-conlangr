// swift-tools-version: 6.0
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
  ],
  dependencies: [
    .package(
      url: "https://github.com/Prosumma/Parsimonious",
      from: "2.5.2"
    ),
  ],
  targets: [
    .target(
      name: "Conlangr",
      dependencies: [
        .product(name: "Parsimonious", package: "Parsimonious")
      ]
    ),
    .testTarget(
        name: "ConlangrTests",
        dependencies: ["Conlangr"]
    ),
  ]
)
