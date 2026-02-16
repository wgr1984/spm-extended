// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SamplePackage",
    platforms: [.macOS(.v12)],
    dependencies: [
        .package(path: "../.."),
        .package(id: "sample.DemoLib", exact: "1.0.0"), // pin to 1.0.0 so outdated shows 1.1.0 available
        .package(url: "https://github.com/apple/swift-numerics", exact: "1.0.0"), // pin to 1.0.0 so outdated shows 1.1.1 available
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
