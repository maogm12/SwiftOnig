// swift-tools-version:6.0

import PackageDescription

let onigurumaSourceFiles: [String] = [
    "CGlobals.c",
    "vendor/regerror.c",
    "vendor/regparse.c",
    "vendor/regext.c",
    "vendor/regcomp.c",
    "vendor/regexec.c",
    "vendor/reggnu.c",
    "vendor/regenc.c",
    "vendor/regsyntax.c",
    "vendor/regtrav.c",
    "vendor/regversion.c",
    "vendor/st.c",
    "vendor/onig_init.c",
    "vendor/unicode.c",
    "vendor/ascii.c",
    "vendor/utf8.c",
    "vendor/utf16_be.c",
    "vendor/utf16_le.c",
    "vendor/utf32_be.c",
    "vendor/utf32_le.c",
    "vendor/euc_jp.c",
    "vendor/sjis.c",
    "vendor/iso8859_1.c",
    "vendor/iso8859_2.c",
    "vendor/iso8859_3.c",
    "vendor/iso8859_4.c",
    "vendor/iso8859_5.c",
    "vendor/iso8859_6.c",
    "vendor/iso8859_7.c",
    "vendor/iso8859_8.c",
    "vendor/iso8859_9.c",
    "vendor/iso8859_10.c",
    "vendor/iso8859_11.c",
    "vendor/iso8859_13.c",
    "vendor/iso8859_14.c",
    "vendor/iso8859_15.c",
    "vendor/iso8859_16.c",
    "vendor/euc_tw.c",
    "vendor/euc_kr.c",
    "vendor/big5.c",
    "vendor/gb18030.c",
    "vendor/koi8_r.c",
    "vendor/cp1251.c",
    "vendor/euc_jp_prop.c",
    "vendor/sjis_prop.c",
    "vendor/unicode_unfold_key.c",
    "vendor/unicode_fold1_key.c",
    "vendor/unicode_fold2_key.c",
    "vendor/unicode_fold3_key.c",
]

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
        .target(
            name: "OnigurumaC",
            path: "Sources/OnigurumaC",
            sources: onigurumaSourceFiles,
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath("."),
                .headerSearchPath("vendor")
            ]),
        .target(
            name: "SwiftOnig",
            dependencies: ["OnigurumaC"],
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
