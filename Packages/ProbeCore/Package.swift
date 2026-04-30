// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ProbeCore",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "ProbeCore", targets: ["ProbeCore"])
    ],
    targets: [
        .target(name: "ProbeCore"),
        .testTarget(
            name: "ProbeCoreTests",
            dependencies: ["ProbeCore"]
        )
    ]
)
