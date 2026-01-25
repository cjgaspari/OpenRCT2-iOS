// swift-tools-version: 6.1
// OpenRCT2 iOS Feature Package

import PackageDescription

let package = Package(
    name: "OpenRCT2iOSFeature",
    platforms: [.iOS(.v17)],
    products: [
        .library(
            name: "OpenRCT2iOSFeature",
            targets: ["OpenRCT2iOSFeature"]
        ),
        .library(
            name: "OpenRCT2Core",
            targets: ["OpenRCT2Core"]
        ),
    ],
    targets: [
        // C wrapper for OpenRCT2 game engine
        .target(
            name: "OpenRCT2Core",
            dependencies: [],
            path: "Sources/OpenRCT2Core",
            sources: ["OpenRCT2Shim.c"],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
                .define("OPENRCT2_IOS", to: "1"),
            ]
        ),

        // Swift feature module with Metal rendering
        .target(
            name: "OpenRCT2iOSFeature",
            dependencies: ["OpenRCT2Core"]
        ),

        .testTarget(
            name: "OpenRCT2iOSFeatureTests",
            dependencies: ["OpenRCT2iOSFeature", "OpenRCT2Core"]
        ),
    ]
)
