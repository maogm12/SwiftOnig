// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "SwiftOnig",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "SwiftOnig",
            targets: ["SwiftOnig"]),
    ],
    dependencies: [
    ],
    targets: [
        .systemLibrary(
            name: "COnig",
            pkgConfig: "oniguruma",
            providers: [
                .apt(["libonig-dev"]),
                .brew(["oniguruma"])
            ]),
        .target(
            name: "OnigInternal",
            dependencies: ["COnig"],
            path: "Sources/OnigInternal"),
        .target(
            name: "SwiftOnig",
            dependencies: ["COnig", "OnigInternal"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]),
        .testTarget(
            name: "SwiftOnigTests",
            dependencies: ["SwiftOnig"]),
        
        // Examples
        .target(
            name: "simple",
            dependencies: ["SwiftOnig"],
            path: "Examples/simple"),
        .target(
            name: "names",
            dependencies: ["SwiftOnig"],
            path: "Examples/names"),
        .target(
            name: "listcap",
            dependencies: ["SwiftOnig"],
            path: "Examples/listcap"),
        .target(
            name: "scan",
            dependencies: ["SwiftOnig"],
            path: "Examples/scan"),
    ]
)
