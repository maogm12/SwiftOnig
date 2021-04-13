// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "SwiftOnig",
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
            name: "SwiftOnig",
            dependencies: ["COnig"]),
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

    ]
)
