// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Concurency",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "Concurency",
            targets: ["Concurency", "Platform"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "Platform",
            path: "Sources/Concurency/Platform"
        ),
        .target(
            name: "Concurency",
            dependencies: [
                "Platform",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "Collections", package: "swift-collections")
            ],
            path: "Sources/Concurency",
            exclude: ["Platform"]
        ),
        .testTarget(
            name: "ConcurencyTests",
            dependencies: ["Concurency", "Platform"],
            path: "Tests/ConcurencyTests"
        ),
    ]
)
