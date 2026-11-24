// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PrijswachtCore",
    defaultLocalization: "nl",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PrijswachtCore", targets: ["PrijswachtCore"])
    ],
    targets: [
        .target(name: "PrijswachtCore"),
        .testTarget(name: "PrijswachtCoreTests", dependencies: ["PrijswachtCore"]),
    ]
)
