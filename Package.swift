// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "asc-metadata-mcp",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.11.0"),
        // Pinned to 1.6.x: asc-swift 1.7.0 introduced breaking API changes
        // (CustomerReview IncludedItem became an enum; AppInfo.Attributes.kidsAgeBand
        // moved) that this code has not yet migrated to. See README for the upgrade note.
        .package(url: "https://github.com/aaronsky/asc-swift.git", .upToNextMinor(from: "1.6.0")),
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
