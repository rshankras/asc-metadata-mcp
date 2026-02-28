import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum CreateVersionTool {
    static let tool = Tool(
        name: "create_version",
        description:
            "Create a new App Store version for an app. Use this before updating metadata for a new release.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "appId": .object(["type": "string", "description": "App Store app ID"]),
                "versionString": .object([
                    "type": "string", "description": "Version number (e.g. \"2.0.0\")",
                ]),
                "platform": .object([
                    "type": "string",
                    "description": "Platform: iOS, macOS, tvOS, or visionOS",
                    "enum": .array([
                        .string("iOS"), .string("macOS"), .string("tvOS"), .string("visionOS"),
                    ]),
                ]),
                "releaseType": .object([
                    "type": "string",
                    "description":
                        "Release type: manual, afterApproval, or scheduled (default: afterApproval)",
                    "enum": .array([
                        .string("manual"), .string("afterApproval"), .string("scheduled"),
                    ]),
                    "default": "afterApproval",
                ]),
                "earliestReleaseDate": .object([
                    "type": "string",
                    "description":
                        "ISO 8601 date for scheduled release (required when releaseType is scheduled)",
                ]),
                "dryRun": .object([
                    "type": "boolean",
                    "description": "Preview changes without applying (default: false)",
                    "default": .bool(false),
                ]),
            ]),
            "required": .array([.string("appId"), .string("versionString"), .string("platform")]),
        ])
    )

    static func handle(
        arguments: [String: Value]?,
        client: AppStoreConnectClient
    ) async throws -> CallTool.Result {
        guard let appId = arguments?["appId"]?.stringValue else {
            return .init(content: [.text("Error: appId is required")], isError: true)
        }
        guard let versionString = arguments?["versionString"]?.stringValue else {
            return .init(content: [.text("Error: versionString is required")], isError: true)
        }
        guard let platformStr = arguments?["platform"]?.stringValue else {
            return .init(content: [.text("Error: platform is required")], isError: true)
        }
        let releaseTypeStr = arguments?["releaseType"]?.stringValue ?? "afterApproval"
        let earliestReleaseDateStr = arguments?["earliestReleaseDate"]?.stringValue
        let dryRun = arguments?["dryRun"]?.boolValue ?? false

        // Map platform string to Platform enum (and corresponding FilterPlatform for queries)
        let platform: Platform
        let filterPlatform: Resources.V1.Apps.WithID.AppStoreVersions.FilterPlatform
        switch platformStr {
        case "iOS": platform = .iOS; filterPlatform = .iOS
        case "macOS": platform = .macOS; filterPlatform = .macOS
        case "tvOS": platform = .tvOS; filterPlatform = .tvOS
        case "visionOS": platform = .visionOS; filterPlatform = .visionOS
        default:
            return .init(
                content: [
                    .text("Error: Invalid platform '\(platformStr)'. Must be iOS, macOS, tvOS, or visionOS")
                ], isError: true)
        }

        // Map releaseType string to ReleaseType enum
        let releaseType: AppStoreVersionCreateRequest.Data.Attributes.ReleaseType
        switch releaseTypeStr {
        case "manual": releaseType = .manual
        case "afterApproval": releaseType = .afterApproval
        case "scheduled": releaseType = .scheduled
        default:
            return .init(
                content: [
                    .text(
                        "Error: Invalid releaseType '\(releaseTypeStr)'. Must be manual, afterApproval, or scheduled"
                    )
                ], isError: true)
        }

        // Parse earliestReleaseDate if scheduled
        var earliestReleaseDate: Date? = nil
        if releaseType == .scheduled {
            guard let dateStr = earliestReleaseDateStr else {
                return .init(
                    content: [
                        .text("Error: earliestReleaseDate is required when releaseType is scheduled")
                    ], isError: true)
            }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateStr) {
                earliestReleaseDate = date
            } else {
                // Try without fractional seconds
                formatter.formatOptions = [.withInternetDateTime]
                guard let date = formatter.date(from: dateStr) else {
                    return .init(
                        content: [
                            .text(
                                "Error: Could not parse earliestReleaseDate '\(dateStr)'. Use ISO 8601 format (e.g. 2026-03-15T10:00:00+00:00)"
                            )
                        ], isError: true)
                }
                earliestReleaseDate = date
            }
        }

        // Check for existing version in PREPARE_FOR_SUBMISSION state
        let versionsResponse = try await client.send(
            Resources.v1.apps.id(appId).appStoreVersions.get(
                filterPlatform: [filterPlatform]
            )
        )
        let existingPrepare = versionsResponse.data.first {
            $0.attributes?.appStoreState == .prepareForSubmission
        }

        var warning: String? = nil
        if let existing = existingPrepare {
            let existingVersion = existing.attributes?.versionString ?? "unknown"
            warning =
                "Warning: Version \(existingVersion) is already in PREPARE_FOR_SUBMISSION state for this platform. Creating a new version will replace it."
        }

        if dryRun {
            var result: [String: Any] = [
                "status": "dry_run",
                "appId": appId,
                "versionString": versionString,
                "platform": platformStr,
                "releaseType": releaseTypeStr,
            ]
            if let date = earliestReleaseDate {
                result["earliestReleaseDate"] = ISO8601DateFormatter().string(from: date)
            }
            if let warning = warning {
                result["warning"] = warning
            }
            let json = try JSONSerialization.data(
                withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            return .init(content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        // Build and send create request
        let request = AppStoreVersionCreateRequest(
            data: .init(
                attributes: .init(
                    platform: platform,
                    versionString: versionString,
                    releaseType: releaseType,
                    earliestReleaseDate: earliestReleaseDate
                ),
                relationships: .init(
                    app: .init(data: .init(id: appId))
                )
            )
        )

        let response = try await client.send(
            Resources.v1.appStoreVersions.post(request)
        )

        let createdVersion = response.data
        var result: [String: Any] = [
            "status": "created",
            "versionId": createdVersion.id,
            "versionString": createdVersion.attributes?.versionString ?? versionString,
            "platform": platformStr,
            "appStoreState": createdVersion.attributes?.appStoreState?.rawValue ?? "unknown",
            "releaseType": releaseTypeStr,
        ]
        if let warning = warning {
            result["warning"] = warning
        }
        let json = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return .init(content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
