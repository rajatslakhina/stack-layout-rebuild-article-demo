// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StackLayoutRebuild",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "StackLayoutCore", targets: ["StackLayoutCore"]),
        .library(name: "StackLayoutUI", targets: ["StackLayoutUI"])
    ],
    targets: [
        .target(name: "StackLayoutCore"),
        .target(name: "StackLayoutUI", dependencies: ["StackLayoutCore"]),
        .testTarget(name: "StackLayoutCoreTests", dependencies: ["StackLayoutCore"])
    ]
)
