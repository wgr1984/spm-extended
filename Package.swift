// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SPMExtendedPlugin",
    platforms: [.macOS(.v12)],
    products: [
        .plugin(
            name: "RegistryPlugin",
            targets: ["RegistryPlugin"]
        ),
        .plugin(
            name: "OutdatedPlugin",
            targets: ["OutdatedPlugin"]
        ),
        .executable(
            name: "spm-extended",
            targets: ["SPMExtendedCLI"]
        ),
    ],
    targets: [
        .target(
            name: "SPMExtendedCore",
            path: "Sources/SPMExtendedCore"
        ),
        .executableTarget(
            name: "SPMExtendedCLI",
            dependencies: ["SPMExtendedCore"],
            path: "Sources/SPMExtendedCLI"
        ),
        .plugin(
            name: "RegistryPlugin",
            capability: .command(
                intent: .custom(
                    verb: "registry",
                    description: "Registry operations with automatic Package.json generation and collection support"
                )
            ),
            path: "Plugins/RegistryPlugin"
        ),
        .plugin(
            name: "OutdatedPlugin",
            capability: .command(
                intent: .custom(
                    verb: "outdated",
                    description: "List current vs available versions for all dependencies (registry and Git)"
                )
            ),
            path: "Plugins/OutdatedPlugin"
        ),
    ]
)
