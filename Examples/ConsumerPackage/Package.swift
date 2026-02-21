// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ConsumerPackage",
    platforms: [.macOS(.v12)],
    dependencies: [
        .package(id: "sample.SamplePackage", exact: "1.0.0-signed"),
    ],
    targets: [
        .executableTarget(
            name: "Consumer",
            dependencies: [
                .product(name: "SamplePackage", package: "sample.SamplePackage"),
            ]
        ),
    ]
)
