// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "VeilServer",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(path: "../Shared"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.115.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.9.0"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.8.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.12.3")
    ],
    targets: [
        .executableTarget(
            name: "VeilServer",
            dependencies: [
                .product(name: "VeilShared", package: "shared"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "Crypto", package: "swift-crypto")
            ],
            swiftSettings: [.enableUpcomingFeature("ExistentialAny")]
        ),
        .testTarget(
            name: "VeilServerTests",
            dependencies: [
                .target(name: "VeilServer"),
                .product(name: "VaporTesting", package: "vapor")
            ],
            swiftSettings: [.enableUpcomingFeature("ExistentialAny")]
        )
    ]
)
