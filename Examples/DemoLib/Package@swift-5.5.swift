// swift-tools-version: 5.5
import PackageDescription

let package = Package(
    name: "DemoLib",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "DemoLib", targets: ["DemoLib"]),
    ],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .target(name: "DemoLib"),
    ]
)
