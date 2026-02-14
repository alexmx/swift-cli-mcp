// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-cli-mcp",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "SwiftCliMcp", targets: ["SwiftCliMcp"])
    ],
    targets: [
        .target(name: "SwiftCliMcp", path: "Sources/SwiftCliMcp")
    ]
)
