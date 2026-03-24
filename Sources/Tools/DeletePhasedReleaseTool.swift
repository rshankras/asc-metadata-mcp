import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum DeletePhasedReleaseTool {
    static let tool = Tool(
        name: "delete_phased_release",
        description:
            "Remove phased release (immediately releases to 100% of users).",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "phasedReleaseId": .object([
                    "type": "string",
                    "description":
                        "Phased release ID to delete (returned by create_phased_release)",
                ]),
                "dryRun": .object([
                    "type": "boolean",
                    "description":
                        "Preview what will be deleted without deleting (default: false)",
                    "default": .bool(false),
                ]),
            ]),
            "required": .array([.string("phasedReleaseId")]),
        ])
    )

    static func handle(
        arguments: [String: Value]?,
        client: AppStoreConnectClient
    ) async throws -> CallTool.Result {
        guard let phasedReleaseId = arguments?["phasedReleaseId"]?.stringValue
        else {
            return .init(
                content: [.text("Error: phasedReleaseId is required")],
                isError: true)
        }
        let dryRun = arguments?["dryRun"]?.boolValue ?? false

        if dryRun {
            let result: [String: Any] = [
                "status": "dry_run",
                "action": "delete_phased_release",
                "phasedReleaseId": phasedReleaseId,
                "warning":
                    "Deleting a phased release will immediately release the version to 100% of users.",
            ]
            let json = try JSONSerialization.data(
                withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            return .init(
                content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        // Delete the phased release
        _ = try await client.send(
            Resources.v1.appStoreVersionPhasedReleases.id(phasedReleaseId).delete
        )

        let result: [String: Any] = [
            "status": "deleted",
            "phasedReleaseId": phasedReleaseId,
            "note":
                "Phased release removed. The version will be immediately available to 100% of users.",
        ]
        let json = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return .init(
            content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
