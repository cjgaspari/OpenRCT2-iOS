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
                "visionos/VisionOSPlatformEnvironment.cpp",
                "visionos/X8DrawingEngineVisionOS.cpp",
                "visionos/InvalidationGridVisionOS.cpp",
                "visionos/RenderTargetVisionOS.cpp",
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
                .define("OPENRCT2_IOS", to: "1"),
                .define("__VISIONOS__", to: "1"),
                .define("CHAR_BIT", to: "8"),
                .define("SCHAR_MAX", to: "127"),
                .define("SCHAR_MIN", to: "(-128)"),
                .define("UCHAR_MAX", to: "255"),
                .define("SHRT_MAX", to: "32767"),
                .define("SHRT_MIN", to: "(-32768)"),
                .define("USHRT_MAX", to: "65535"),
                .define("INT_MAX", to: "2147483647"),
                .define("INT_MIN", to: "(-2147483647-1)"),
                .define("UINT_MAX", to: "4294967295U"),
                .define("LONG_MAX", to: "9223372036854775807L"),
                .define("LONG_MIN", to: "(-9223372036854775807L-1)"),
                .define("ULONG_MAX", to: "18446744073709551615UL"),
                .define("LLONG_MAX", to: "9223372036854775807LL"),
                .define("LLONG_MIN", to: "(-9223372036854775807LL-1)"),
                .define("ULLONG_MAX", to: "18446744073709551615ULL"),
                .unsafeFlags(["-std=c++20"]),
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
