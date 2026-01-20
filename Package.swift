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
    ],
    targets: [
        .plugin(
            name: "RegistryPlugin",
            capability: .command(
                intent: .custom(
                    verb: "registry",
                    description: "Registry operations with automatic Package.json generation and collection support"
                )
            )
        ),
    ]
)
