// swift-tools-version:5.8

import PackageDescription

let package = Package(
    name: "BrowserKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        .library(
            name: "BrowserKit",
            targets: ["BrowserKit"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/vmanot/CorePersistence.git", branch: "main"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", exact: "2.6.0"),
        .package(url: "https://github.com/vmanot/NetworkKit.git", branch: "master"),
        .package(url: "https://github.com/vmanot/Swallow.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "BrowserKit",
            dependencies: [
                "CorePersistence",
                "NetworkKit",
                "Swallow",
                "SwiftSoup"
            ],
            path: "Sources",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "BrowserKitTests",
            dependencies: [
                "BrowserKit"
            ],
            path: "Tests"
        )
    ]
)
