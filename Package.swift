// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "asc-metadata-mcp",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.11.0"),
        .package(url: "https://github.com/aaronsky/asc-swift.git", from: "1.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "asc-metadata-mcp",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "AppStoreConnect", package: "asc-swift"),
            ],
            path: "Sources"
        ),
    ]
)
