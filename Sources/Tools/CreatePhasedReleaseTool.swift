import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum CreatePhasedReleaseTool {
    static let tool = Tool(
        name: "create_phased_release",
        description:
            "Enable phased release for an App Store version. Rolls out to users gradually over 7 days.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "versionId": .object([
                    "type": "string",
                    "description": "App Store version ID to enable phased release for",
                ]),
                "dryRun": .object([
                    "type": "boolean",
                    "description":
                        "Preview changes without applying (default: false)",
                    "default": .bool(false),
                ]),
            ]),
            "required": .array([.string("versionId")]),
        ])
    )

    static func handle(
        arguments: [String: Value]?,
        client: AppStoreConnectClient
    ) async throws -> CallTool.Result {
        guard let versionId = arguments?["versionId"]?.stringValue else {
            return .init(
                content: [.text("Error: versionId is required")], isError: true)
        }
        let dryRun = arguments?["dryRun"]?.boolValue ?? false

        // Check if phased release already exists for this version
        let existingResponse = try? await client.send(
            Resources.v1.appStoreVersions.id(versionId)
                .appStoreVersionPhasedRelease.get()
        )

        if let existing = existingResponse?.data {
            let attrs = existing.attributes
            var info: [String: Any] = [
                "status": "already_exists",
                "phasedReleaseId": existing.id,
                "phasedReleaseState": attrs?.phasedReleaseState?.rawValue ?? "",
            ]
            if let day = attrs?.currentDayNumber { info["currentDayNumber"] = day }
            if let startDate = attrs?.startDate {
                info["startDate"] = ISO8601DateFormatter().string(from: startDate)
            }
            if let pauseDuration = attrs?.totalPauseDuration {
                info["totalPauseDuration"] = pauseDuration
            }
            let json = try JSONSerialization.data(
                withJSONObject: info, options: [.prettyPrinted, .sortedKeys])
            return .init(
                content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        if dryRun {
            let result: [String: Any] = [
                "status": "dry_run",
                "action": "create_phased_release",
                "versionId": versionId,
                "phasedReleaseState": "INACTIVE",
                "note":
                    "Phased release will be created in INACTIVE state. It activates when the version is released.",
            ]
            let json = try JSONSerialization.data(
                withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            return .init(
                content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        // Create phased release
        let request = AppStoreVersionPhasedReleaseCreateRequest(
            data: .init(
                attributes: .init(phasedReleaseState: .inactive),
                relationships: .init(
                    appStoreVersion: .init(data: .init(id: versionId))
                )
            )
        )

        let response = try await client.send(
            Resources.v1.appStoreVersionPhasedReleases.post(request)
        )
        let created = response.data
        let attrs = created.attributes

        var result: [String: Any] = [
            "status": "created",
            "phasedReleaseId": created.id,
            "versionId": versionId,
            "phasedReleaseState": attrs?.phasedReleaseState?.rawValue ?? "",
        ]
        if let day = attrs?.currentDayNumber { result["currentDayNumber"] = day }
        if let startDate = attrs?.startDate {
            result["startDate"] = ISO8601DateFormatter().string(from: startDate)
        }
        if let pauseDuration = attrs?.totalPauseDuration {
            result["totalPauseDuration"] = pauseDuration
        }

        let json = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return .init(
            content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
