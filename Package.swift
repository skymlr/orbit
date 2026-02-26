// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Orbit",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "OrbitApp", targets: ["OrbitApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.16.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.8.0"),
        .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.13.0"),
    ],
    targets: [
        .executableTarget(
            name: "OrbitApp",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Parsing", package: "swift-parsing"),
            ]
        ),
        .testTarget(
            name: "OrbitAppTests",
            dependencies: [
                "OrbitApp",
            ]
        ),
    ]
)
