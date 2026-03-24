import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum UpdateBetaGroupTool {
    static let tool = Tool(
        name: "update_beta_group",
        description:
            "Update a TestFlight beta group's settings. Shows old/new diff.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "groupId": .object([
                    "type": "string",
                    "description": "Beta group ID to update",
                ]),
                "name": .object([
                    "type": "string",
                    "description": "New name for the group",
                ]),
                "publicLinkEnabled": .object([
                    "type": "boolean",
                    "description": "Enable or disable public link",
                ]),
                "publicLinkLimit": .object([
                    "type": "integer",
                    "description": "Maximum testers via public link",
                ]),
                "publicLinkLimitEnabled": .object([
                    "type": "boolean",
                    "description": "Enable or disable public link limit",
                ]),
                "feedbackEnabled": .object([
                    "type": "boolean",
                    "description": "Enable or disable tester feedback",
                ]),
                "dryRun": .object([
                    "type": "boolean",
                    "description":
                        "Preview changes without applying (default: false)",
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

        let newName = arguments?["name"]?.stringValue
        let newPublicLinkEnabled = arguments?["publicLinkEnabled"]?.boolValue
        let newPublicLinkLimit = arguments?["publicLinkLimit"]?.intValue
        let newPublicLinkLimitEnabled =
            arguments?["publicLinkLimitEnabled"]?.boolValue
        let newFeedbackEnabled = arguments?["feedbackEnabled"]?.boolValue
        let dryRun = arguments?["dryRun"]?.boolValue ?? false

        guard
            newName != nil || newPublicLinkEnabled != nil
                || newPublicLinkLimit != nil || newPublicLinkLimitEnabled != nil
                || newFeedbackEnabled != nil
        else {
            return .init(
                content: [
                    .text(
                        "Error: At least one field to update must be provided")
                ],
                isError: true)
        }

        // Fetch current group
        let currentResponse = try await client.send(
            Resources.v1.betaGroups.id(groupId).get(
                fieldsBetaGroups: [
                    .name, .publicLinkEnabled, .publicLinkLimit,
                    .publicLinkLimitEnabled, .feedbackEnabled,
                    .isInternalGroup, .publicLink,
                ]
            )
        )

        let current = currentResponse.data
        let currentAttrs = current.attributes

        // Build changes dict
        var changes: [String: Any] = [:]

        if let v = newName {
            changes["name"] = [
                "old": currentAttrs?.name ?? "",
                "new": v,
            ]
        }
        if let v = newPublicLinkEnabled {
            changes["publicLinkEnabled"] = [
                "old": currentAttrs?.isPublicLinkEnabled ?? false,
                "new": v,
            ]
        }
        if let v = newPublicLinkLimit {
            changes["publicLinkLimit"] = [
                "old": currentAttrs?.publicLinkLimit ?? 0,
                "new": v,
            ]
        }
        if let v = newPublicLinkLimitEnabled {
            changes["publicLinkLimitEnabled"] = [
                "old": currentAttrs?.isPublicLinkLimitEnabled ?? false,
                "new": v,
            ]
        }
        if let v = newFeedbackEnabled {
            changes["feedbackEnabled"] = [
                "old": currentAttrs?.isFeedbackEnabled ?? false,
                "new": v,
            ]
        }

        if dryRun {
            let result: [String: Any] = [
                "status": "dry_run",
                "groupId": groupId,
                "groupName": currentAttrs?.name ?? "",
                "changes": changes,
            ]
            let json = try JSONSerialization.data(
                withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            return .init(
                content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        // Apply update
        let updateAttrs = BetaGroupUpdateRequest.Data.Attributes(
            name: newName,
            isPublicLinkEnabled: newPublicLinkEnabled,
            isPublicLinkLimitEnabled: newPublicLinkLimitEnabled,
            publicLinkLimit: newPublicLinkLimit,
            isFeedbackEnabled: newFeedbackEnabled
        )

        let request = BetaGroupUpdateRequest(
            data: .init(
                id: groupId,
                attributes: updateAttrs
            )
        )

        _ = try await client.send(
            Resources.v1.betaGroups.id(groupId).patch(request)
        )

        let result: [String: Any] = [
            "status": "updated",
            "groupId": groupId,
            "changes": changes,
        ]
        let json = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return .init(
            content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
