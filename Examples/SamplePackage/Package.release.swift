// swift-tools-version: 5.9
// Used when publishing to registry (no path dependency). Restored after test-publish-signing.
import PackageDescription

let package = Package(
    name: "SamplePackage",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "SamplePackage", targets: ["SamplePackage"]),
    ],
    dependencies: [
        .package(id: "sample.DemoLib", exact: "1.0.0"),
        .package(url: "https://github.com/apple/swift-numerics", exact: "1.0.0"),
    ],
    targets: [
        .target(
            name: "SamplePackage",
            dependencies: [
                .product(name: "Numerics", package: "swift-numerics"),
                .product(name: "DemoLib", package: "sample.demolib"),
            ]
        ),
    ]
)
