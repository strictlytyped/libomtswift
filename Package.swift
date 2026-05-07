// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "LibOMTSwift",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "LibOMTSwift",
            targets: ["LibOMTSwift"]
        )
    ],
    targets: [
        .target(
            name: "LibOMTSwift",
            dependencies: ["LibOMTVMXShim"]
        ),
        .target(
            name: "LibOMTVMXShim",
            publicHeadersPath: "include"
        ),
        .testTarget(
            name: "LibOMTSwiftTests",
            dependencies: ["LibOMTSwift"]
        )
    ]
)
