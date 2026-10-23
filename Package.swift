// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "asc-metadata-mcp",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.11.0"),
        .package(url: "https://github.com/aaronsky/asc-swift.git", from: "1.7.0"),
    ],
    targets: [
        // Pure, dependency-free helpers — unit-tested in isolation.
        .target(
            name: "ASCMetadataCore",
            path: "Sources/ASCMetadataCore"
        ),
        .executableTarget(
            name: "asc-metadata-mcp",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "AppStoreConnect", package: "asc-swift"),
                "ASCMetadataCore",
            ],
            path: "Sources/asc-metadata-mcp"
        ),
        .testTarget(
            name: "ASCMetadataCoreTests",
            dependencies: ["ASCMetadataCore"],
            path: "Tests/ASCMetadataCoreTests"
        ),
    ]
)
