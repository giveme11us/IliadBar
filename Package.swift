// swift-tools-version:6.0
import PackageDescription

let package = Package(
  name: "iliadbar",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "IliadboxKit", targets: ["IliadboxKit"]),
    .executable(name: "ibx", targets: ["ibx"]),
    .executable(name: "IliadBar", targets: ["IliadBar"]),
    .executable(name: "IliadBarWidget", targets: ["IliadBarWidget"]),
  ],
  dependencies: [
    .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.2")
  ],
  targets: [
    .target(
      name: "IliadboxKit",
      linkerSettings: [
        .linkedFramework("Security"),
        .linkedFramework("LocalAuthentication"),
      ]
    ),
    .executableTarget(name: "ibx", dependencies: ["IliadboxKit"]),
    .executableTarget(
      name: "IliadBar",
      dependencies: [
        "IliadboxKit",
        .product(name: "Sparkle", package: "Sparkle"),
      ]),
    .executableTarget(name: "IliadBarWidget", dependencies: ["IliadboxKit"]),
    .testTarget(name: "IliadboxKitTests", dependencies: ["IliadboxKit"]),
  ]
)
