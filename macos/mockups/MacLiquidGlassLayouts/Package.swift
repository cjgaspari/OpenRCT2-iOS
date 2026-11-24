// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MacLiquidGlassLayouts",
    platforms: [
        .macOS(.v26),
    ],
    targets: [
        .executableTarget(
            name: "MacLiquidGlassLayouts",
            path: "Sources/MacLiquidGlassLayouts",
            resources: [
                .process("Resources"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
    ]
)
