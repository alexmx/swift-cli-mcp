// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-cli-mcp",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "SwiftMCP", targets: ["SwiftMCP"]),
        .executable(name: "test-server", targets: ["TestServer"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-atomics.git", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "SwiftMCP",
            dependencies: [
                .product(name: "Atomics", package: "swift-atomics")
            ],
            path: "Sources/SwiftCliMcp"
        ),
        .executableTarget(
            name: "TestServer",
            dependencies: ["SwiftMCP"],
            path: "Sources/TestServer"
        ),
        .testTarget(
            name: "SwiftCliMcpTests",
            dependencies: ["SwiftMCP"]
        )
    ]
)
