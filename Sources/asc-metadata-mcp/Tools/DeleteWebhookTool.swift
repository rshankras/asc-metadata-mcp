import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum DeleteWebhookTool {
    static let tool = Tool(
        name: "delete_webhook",
        description:
            "Delete a webhook. Fetches webhook details before deleting for confirmation.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "webhookId": .object([
                    "type": "string",
                    "description": "Webhook ID to delete",
                ]),
                "dryRun": .object([
                    "type": "boolean",
                    "description":
                        "Preview what will be deleted without deleting (default: false)",
                    "default": .bool(false),
                ]),
            ]),
            "required": .array([.string("webhookId")]),
        ])
    )

    static func handle(
        arguments: [String: Value]?,
        client: AppStoreConnectClient
    ) async throws -> CallTool.Result {
        guard let webhookId = arguments?["webhookId"]?.stringValue else {
            return .init(
                content: [.text("Error: webhookId is required")], isError: true)
        }
        let dryRun = arguments?["dryRun"]?.boolValue ?? false

        // Fetch webhook details for confirmation
        let currentResponse = try await client.send(
            Resources.v1.webhooks.id(webhookId).get(
                fieldsWebhooks: [.enabled, .eventTypes, .name, .url]
            )
        )

        let webhook = currentResponse.data
        let attrs = webhook.attributes

        var webhookInfo: [String: Any] = [
            "webhookId": webhook.id,
            "name": attrs?.name ?? "",
        ]
        if let url = attrs?.url {
            webhookInfo["url"] = url.absoluteString
        }
        if let v = attrs?.isEnabled { webhookInfo["enabled"] = v }
        if let eventTypes = attrs?.eventTypes {
            webhookInfo["eventTypes"] = eventTypes.map(\.rawValue)
        }

        if dryRun {
            let result: [String: Any] = [
                "status": "dry_run",
                "action": "delete",
                "webhook": webhookInfo,
            ]
            let json = try JSONSerialization.data(
                withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            return .init(
                content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        // Delete the webhook
        _ = try await client.send(
            Resources.v1.webhooks.id(webhookId).delete)

        let result: [String: Any] = [
            "status": "deleted",
            "webhook": webhookInfo,
        ]
        let json = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return .init(
            content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
