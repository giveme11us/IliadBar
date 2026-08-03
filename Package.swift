// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "iliadbar",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "IliadboxKit", targets: ["IliadboxKit"]),
        .executable(name: "ibx", targets: ["ibx"]),
        .executable(name: "IliadBar", targets: ["IliadBar"]),
    ],
    targets: [
        .target(name: "IliadboxKit"),
        .executableTarget(name: "ibx", dependencies: ["IliadboxKit"]),
        .executableTarget(name: "IliadBar", dependencies: ["IliadboxKit"]),
    ]
)
