import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum DeleteBetaGroupTool {
    static let tool = Tool(
        name: "delete_beta_group",
        description:
            "Delete a TestFlight beta group. Fetches group details before deleting for confirmation.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "groupId": .object([
                    "type": "string",
                    "description": "Beta group ID to delete",
                ]),
                "dryRun": .object([
                    "type": "boolean",
                    "description":
                        "Preview what will be deleted without deleting (default: false)",
                    "default": .bool(false),
                ]),
            ]),
            "required": .array([.string("groupId")]),
        ])
    )

    static func handle(
        arguments: [String: Value]?,
        client: AppStoreConnectClient
    ) async throws -> CallTool.Result {
        guard let groupId = arguments?["groupId"]?.stringValue else {
            return .init(
                content: [.text("Error: groupId is required")], isError: true)
        }
        let dryRun = arguments?["dryRun"]?.boolValue ?? false

        // Fetch group details for confirmation
        let currentResponse = try await client.send(
            Resources.v1.betaGroups.id(groupId).get(
                fieldsBetaGroups: [
                    .name, .isInternalGroup, .createdDate,
                    .publicLinkEnabled, .publicLink, .feedbackEnabled,
                    .hasAccessToAllBuilds,
                ]
            )
        )

        let group = currentResponse.data
        let attrs = group.attributes

        let formatter = ISO8601DateFormatter()

        var groupInfo: [String: Any] = [
            "groupId": group.id,
            "name": attrs?.name ?? "",
        ]
        if let v = attrs?.isInternalGroup { groupInfo["isInternalGroup"] = v }
        if let v = attrs?.createdDate {
            groupInfo["createdDate"] = formatter.string(from: v)
        }
        if let v = attrs?.isPublicLinkEnabled {
            groupInfo["publicLinkEnabled"] = v
        }
        if let v = attrs?.publicLink { groupInfo["publicLink"] = v }
        if let v = attrs?.isFeedbackEnabled {
            groupInfo["feedbackEnabled"] = v
        }
        if let v = attrs?.hasAccessToAllBuilds {
            groupInfo["hasAccessToAllBuilds"] = v
        }

        if dryRun {
            let result: [String: Any] = [
                "status": "dry_run",
                "action": "delete",
                "group": groupInfo,
            ]
            let json = try JSONSerialization.data(
                withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            return .init(
                content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        // Delete the group
        _ = try await client.send(
            Resources.v1.betaGroups.id(groupId).delete)

        let result: [String: Any] = [
            "status": "deleted",
            "group": groupInfo,
        ]
        let json = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return .init(
            content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
