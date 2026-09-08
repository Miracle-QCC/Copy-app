// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ClipStack",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ClipStack", targets: ["ClipStack"])
    ],
    targets: [
        .executableTarget(
            name: "ClipStack",
            exclude: ["Resources"]
        ),
        .testTarget(
            name: "ClipStackTests",
            dependencies: ["ClipStack"]
        )
    ]
)
