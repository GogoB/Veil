// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "VeilShared",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "VeilShared", targets: ["VeilShared"])
    ],
    targets: [
        .target(name: "VeilShared"),
        .testTarget(name: "VeilSharedTests", dependencies: ["VeilShared"])
    ]
)
