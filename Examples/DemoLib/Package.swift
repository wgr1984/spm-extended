// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DemoLib",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "DemoLib", targets: ["DemoLib"]),
    ],
    dependencies: [
        .package(path: "../.."), // plugin for registry publish
    ],
    targets: [
        .target(name: "DemoLib"),
    ]
)
