// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HarvestBinCommands",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "HarvestBinCommandsCore", targets: ["HarvestBinCommandsCore"]),
        .library(name: "HarvestBinCommandsDefaults", targets: ["HarvestBinCommandsDefaults"]),
        .library(name: "HarvestBinCommands", targets: ["HarvestBinCommands"]),
        .executable(name: "HarvestBinCommandsDemo", targets: ["HarvestBinCommandsDemo"])
    ],
    dependencies: [
        // Using Foundation.Process instead of external dependencies
    ],
    targets: [
        .target(
            name: "HarvestBinCommandsCore",
            dependencies: []
        ),
        .target(
            name: "HarvestBinCommandsDefaults",
            dependencies: ["HarvestBinCommandsCore"]
        ),
        .target(
            name: "HarvestBinCommands",
            dependencies: ["HarvestBinCommandsDefaults"]
        ),
        .executableTarget(
            name: "HarvestBinCommandsDemo",
            dependencies: ["HarvestBinCommands"]
        ),
        .testTarget(
            name: "HarvestBinCommandsCoreTests",
            dependencies: ["HarvestBinCommandsCore"]
        ),
        .testTarget(
            name: "HarvestBinCommandsDefaultsTests",
            dependencies: ["HarvestBinCommandsDefaults"]
        ),
        .testTarget(
            name: "HarvestBinCommandsTests",
            dependencies: ["HarvestBinCommands"]
        )
    ]
)