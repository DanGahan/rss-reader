// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift Package Manager
// required to build this package.

import PackageDescription

let package = Package(
    name: "RSSReader",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "RSSReaderLib",
            targets: ["RSSReader"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftlang/swift-testing.git",
            branch: "main"
        )
    ],
    targets: [
        .target(
            name: "RSSReader",
            path: "RSSReader",
            exclude: [
                "Info.plist",
                "RSSReader.entitlements",
                "App/RSSReaderApp.swift"
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "RSSReaderTests",
            dependencies: [
                "RSSReader",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "RSSReaderTests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
