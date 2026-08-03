// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "magnetbox",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "IliadboxKit", targets: ["IliadboxKit"]),
        .executable(name: "ibx", targets: ["ibx"]),
        .executable(name: "MagnetBox", targets: ["MagnetBox"]),
    ],
    targets: [
        .target(name: "IliadboxKit"),
        .executableTarget(name: "ibx", dependencies: ["IliadboxKit"]),
        .executableTarget(name: "MagnetBox", dependencies: ["IliadboxKit"]),
    ]
)
