import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum ListWebhooksTool {
    static let tool = Tool(
        name: "list_webhooks",
        description:
            "List webhooks configured for an app. Shows URL, event subscriptions, and enabled state.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "appId": .object([
                    "type": "string",
                    "description": "App Store app ID",
                ])
            ]),
            "required": .array([.string("appId")]),
        ])
    )

    static func handle(
        arguments: [String: Value]?,
        client: AppStoreConnectClient
    ) async throws -> CallTool.Result {
        guard let appId = arguments?["appId"]?.stringValue else {
            return .init(
                content: [.text("Error: appId is required")], isError: true)
        }

        let response = try await client.send(
            Resources.v1.apps.id(appId).webhooks.get(
                fieldsWebhooks: [.enabled, .eventTypes, .name, .url],
                limit: 200
            )
        )

        var webhooks: [[String: Any]] = []

        for webhook in response.data {
            let attrs = webhook.attributes
            var webhookDict: [String: Any] = [
                "webhookId": webhook.id,
                "name": attrs?.name ?? "",
            ]
            if let url = attrs?.url {
                webhookDict["url"] = url.absoluteString
            }
            if let v = attrs?.isEnabled {
                webhookDict["enabled"] = v
            }
            if let eventTypes = attrs?.eventTypes {
                webhookDict["eventTypes"] = eventTypes.map(\.rawValue)
            }

            webhooks.append(webhookDict)
        }

        let result: [String: Any] = [
            "webhooks": webhooks,
            "count": webhooks.count,
        ]
        let json = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return .init(
            content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
