// swift-tools-version:5.7

import PackageDescription

let package = Package(
  name: "SimpleOCRServer",
  platforms: [
    .macOS(.v10_15)
  ],
  products: [
    .executable(name: "simple_ocr_server", targets: ["SimpleOCRServer"])
  ],
  dependencies: [
    .package(url: "https://github.com/swhitty/FlyingFox.git", .upToNextMajor(from: "0.11.1"))
  ],
  targets: [
    .executableTarget(
      name: "SimpleOCRServer",
      dependencies: [
        .product(name: "FlyingFox", package: "FlyingFox")
      ],
      path: "Sources"
    )
  ]
)
