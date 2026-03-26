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
        .package(url: "https://github.com/apple/swift-testing.git", exact: "0.10.0"),
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
            dependencies: [
                "SwiftOnig",
                .product(name: "Testing", package: "swift-testing")
            ]),
        
        // Examples
        .executableTarget(
            name: "simple",
            dependencies: ["SwiftOnig"],
            path: "Examples/simple"),
        .executableTarget(
            name: "names",
            dependencies: ["SwiftOnig"],
            path: "Examples/names"),
        .executableTarget(
            name: "listcap",
            dependencies: ["SwiftOnig"],
            path: "Examples/listcap"),
        .executableTarget(
            name: "scan",
            dependencies: ["SwiftOnig"],
            path: "Examples/scan"),
            
        // Benchmarks
        .executableTarget(
            name: "SwiftOnigBenchmarks",
            dependencies: ["SwiftOnig"],
            path: "Benchmarks"),
    ]
)
