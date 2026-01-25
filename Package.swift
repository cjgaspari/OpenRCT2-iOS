// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "OpenRCT2iOS",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v2),
    ],
    products: [
        .library(name: "OpenRCT2Core", targets: ["OpenRCT2Core"]),
        .executable(name: "OpenRCT2App", targets: ["OpenRCT2App"]),
    ],
    targets: [
        // C wrapper target for OpenRCT2 game engine
        .target(
            name: "OpenRCT2Core",
            dependencies: [],
            path: "Sources/OpenRCT2Core",
            exclude: [],
            sources: ["OpenRCT2Shim.c"],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
                .define("OPENRCT2_IOS", to: "1"),
            ],
            cxxSettings: [
                .define("OPENRCT2_IOS", to: "1"),
            ]
        ),

        // iOS app target
        .executableTarget(
            name: "OpenRCT2App",
            dependencies: ["OpenRCT2Core"],
            path: "Sources/OpenRCT2App",
            resources: [
                .process("Shaders.metal")
            ],
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals")
            ]
        ),

        // Tests
        .testTarget(
            name: "OpenRCT2CoreTests",
            dependencies: ["OpenRCT2Core"],
            path: "Tests/OpenRCT2CoreTests"
        ),
    ]
)
