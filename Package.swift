// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "OpenRCT2iOS",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1),
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
            sources: [
                "OpenRCT2Shim.cpp",
                "visionos/VisionOSUiContext.cpp",
            ],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
                .headerSearchPath("../../src"),
                .headerSearchPath("../../src/openrct2"),
                .define("OPENRCT2_IOS", to: "1"),
                .define("__VISIONOS__", to: "1"),
                .define("CHAR_BIT", to: "8"),
            ],
            cxxSettings: [
                .headerSearchPath("../../src"),
                .headerSearchPath("../../src/openrct2"),
                .define("OPENRCT2_IOS", to: "1"),
                .define("__VISIONOS__", to: "1"),
                .define("CHAR_BIT", to: "8"),
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
