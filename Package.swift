// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Orbit",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(name: "OrbitApp", targets: ["OrbitApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.16.0"),
        .package(url: "https://github.com/pointfreeco/swift-case-paths", from: "1.5.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.8.0"),
        .package(url: "https://github.com/pointfreeco/sqlite-data", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-structured-queries", from: "0.1.0"),
        .package(url: "https://github.com/tevelee/SwiftUI-Flow.git", from: "3.1.1"),
    ],
    targets: [
        .target(
            name: "OrbitApp",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "CasePaths", package: "swift-case-paths"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "SQLiteData", package: "sqlite-data"),
                .product(name: "StructuredQueries", package: "swift-structured-queries"),
                .product(name: "Flow", package: "swiftui-flow"),
            ],
            exclude: [
                "App/macOS/OrbitMacApp.swift",
                "App/iOS/OrbitIOSApp.swift",
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
