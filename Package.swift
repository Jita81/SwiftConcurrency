// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Concurency",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "Concurency",
            targets: ["Concurency"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "0.1.0")
    ],
    targets: [
        .target(
            name: "Concurency",
            dependencies: [
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")
            ],
            swiftSettings: [
                .define("SWIFT_PACKAGE"),
                .define("DEBUG", .when(configuration: .debug))
            ]),
        .testTarget(
            name: "ConcurencyTests",
            dependencies: ["Concurency"])
    ]
)
