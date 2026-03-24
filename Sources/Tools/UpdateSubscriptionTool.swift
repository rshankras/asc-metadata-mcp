import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum UpdateSubscriptionTool {
    static let tool = Tool(
        name: "update_subscription",
        description: "Update a subscription's metadata. Shows old/new diff.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "subscriptionId": .object([
                    "type": "string",
                    "description": "Subscription ID to update",
                ]),
                "name": .object([
                    "type": "string",
                    "description": "New display name for the subscription",
                ]),
                "reviewNote": .object([
                    "type": "string",
                    "description": "Note for App Review about this subscription",
                ]),
                "familySharable": .object([
                    "type": "boolean",
                    "description": "Whether the subscription supports Family Sharing",
                ]),
                "groupLevel": .object([
                    "type": "integer",
                    "description":
                        "Level of service within the subscription group (1 is highest)",
                ]),
                "dryRun": .object([
                    "type": "boolean",
                    "description":
                        "Preview changes without applying (default: false)",
                    "default": .bool(false),
                ]),
            ]),
            "required": .array([.string("subscriptionId")]),
        ])
    )

    static func handle(
        arguments: [String: Value]?,
        client: AppStoreConnectClient
    ) async throws -> CallTool.Result {
        guard let subscriptionId = arguments?["subscriptionId"]?.stringValue else {
            return .init(
                content: [.text("Error: subscriptionId is required")], isError: true)
        }

        let newName = arguments?["name"]?.stringValue
        let newReviewNote = arguments?["reviewNote"]?.stringValue
        let newFamilySharable = arguments?["familySharable"]?.boolValue
        let newGroupLevel = arguments?["groupLevel"]?.intValue
        let dryRun = arguments?["dryRun"]?.boolValue ?? false

        // Ensure at least one field is being updated
        guard
            newName != nil || newReviewNote != nil || newFamilySharable != nil
                || newGroupLevel != nil
        else {
            return .init(
                content: [
                    .text(
                        "Error: At least one field to update must be provided (name, reviewNote, familySharable, groupLevel)"
                    )
                ],
                isError: true)
        }

        // Fetch current subscription
        let currentResponse = try await client.send(
            Resources.v1.subscriptions.id(subscriptionId).get()
        )
        let current = currentResponse.data
        let attrs = current.attributes

        // Build changes dict
        var changes: [String: Any] = [:]

        if let newName = newName {
            changes["name"] = [
                "old": attrs?.name ?? "", "new": newName,
            ]
        }
        if let newReviewNote = newReviewNote {
            changes["reviewNote"] = [
                "old": attrs?.reviewNote ?? "", "new": newReviewNote,
            ]
        }
        if let newFS = newFamilySharable {
            changes["familySharable"] = [
                "old": attrs?.isFamilySharable ?? false, "new": newFS,
            ]
        }
        if let newGL = newGroupLevel {
            changes["groupLevel"] = [
                "old": attrs?.groupLevel ?? 0, "new": newGL,
            ]
        }

        if dryRun {
            let result: [String: Any] = [
                "status": "dry_run",
                "subscriptionId": subscriptionId,
                "changes": changes,
            ]
            let json = try JSONSerialization.data(
                withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            return .init(
                content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        // Apply update
        let updateRequest = SubscriptionUpdateRequest(
            data: .init(
                id: subscriptionId,
                attributes: .init(
                    name: newName,
                    isFamilySharable: newFamilySharable,
                    reviewNote: newReviewNote,
                    groupLevel: newGroupLevel
                )
            )
        )

        _ = try await client.send(
            Resources.v1.subscriptions.id(subscriptionId).patch(updateRequest)
        )

        let result: [String: Any] = [
            "status": "updated",
            "subscriptionId": subscriptionId,
            "changes": changes,
        ]
        let json = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return .init(
            content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
