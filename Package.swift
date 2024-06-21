// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "URLMockProtocol",
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "URLMockProtocol", targets: ["URLMockProtocol"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "URLMockProtocol",
            dependencies: [],
            path: "src"
        ),
        .testTarget(
            name: "URLMockProtocolTests",
            dependencies: ["URLMockProtocol"],
            path: "tests"
        )
    ]
)
