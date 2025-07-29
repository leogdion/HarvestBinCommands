// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HarvestBinCommands",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "HarvestBinCommandsCore", targets: ["HarvestBinCommandsCore"]),
        .library(name: "HarvestBinCommandsDefaults", targets: ["HarvestBinCommandsDefaults"]),
        .library(name: "HarvestBinCommands", targets: ["HarvestBinCommands"]),
        .executable(name: "HarvestBinCommandsDemo", targets: ["HarvestBinCommandsDemo"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-subprocess.git", branch: "main")
    ],
    targets: [
        .target(
            name: "HarvestBinCommandsCore",
            dependencies: [
                .product(name: "Subprocess", package: "swift-subprocess")
            ]
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