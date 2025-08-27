// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "SemanticBrowser",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SemanticBrowser",
            targets: ["SemanticBrowser"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.59.0"),
        .package(url: "https://github.com/typesense/typesense-swift.git", from: "1.0.1")
    ],
    targets: [
        .target(
            name: "SemanticBrowser",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
                .product(name: "Typesense", package: "typesense-swift")
            ]
        ),
        .testTarget(
            name: "SemanticBrowserTests",
            dependencies: [
                "SemanticBrowser"
            ]
        )
    ]
)
