import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum UpdateWebhookTool {
    static let tool = Tool(
        name: "update_webhook",
        description:
            "Update a webhook's URL, name, secret, event subscriptions, or enabled state. Shows old/new diff.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "webhookId": .object([
                    "type": "string",
                    "description": "Webhook ID to update",
                ]),
                "name": .object([
                    "type": "string",
                    "description": "New name for the webhook",
                ]),
                "url": .object([
                    "type": "string",
                    "description": "New webhook endpoint URL",
                ]),
                "secret": .object([
                    "type": "string",
                    "description": "New shared secret",
                ]),
                "eventTypes": .object([
                    "type": "array",
                    "description": "New event type subscriptions",
                    "items": .object([
                        "type": "string"
                    ]),
                ]),
                "enabled": .object([
                    "type": "boolean",
                    "description": "Enable or disable the webhook",
                ]),
                "dryRun": .object([
                    "type": "boolean",
                    "description":
                        "Preview changes without applying (default: false)",
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

        let newName = arguments?["name"]?.stringValue
        let newUrlStr = arguments?["url"]?.stringValue
        let newSecret = arguments?["secret"]?.stringValue
        let newEnabled = arguments?["enabled"]?.boolValue
        let eventTypeValues = arguments?["eventTypes"]?.arrayValue
        let dryRun = arguments?["dryRun"]?.boolValue ?? false

        guard
            newName != nil || newUrlStr != nil || newSecret != nil
                || newEnabled != nil || eventTypeValues != nil
        else {
            return .init(
                content: [
                    .text(
                        "Error: At least one field to update must be provided")
                ],
                isError: true)
        }

        // Parse new URL if provided
        var newUrl: URL?
        if let urlStr = newUrlStr {
            guard let parsed = URL(string: urlStr) else {
                return .init(
                    content: [.text("Error: Invalid URL '\(urlStr)'")],
                    isError: true)
            }
            newUrl = parsed
        }

        // Parse new event types if provided
        var newEventTypes: [WebhookEventType]?
        if let eventTypeValues = eventTypeValues {
            var parsed: [WebhookEventType] = []
            for value in eventTypeValues {
                guard let str = value.stringValue else {
                    return .init(
                        content: [
                            .text(
                                "Error: eventTypes must be an array of strings")
                        ],
                        isError: true)
                }
                guard let eventType = WebhookEventType(rawValue: str) else {
                    let validTypes = WebhookEventType.allCases.map(\.rawValue)
                        .joined(separator: ", ")
                    return .init(
                        content: [
                            .text(
                                "Error: Invalid event type '\(str)'. Valid types: \(validTypes)"
                            )
                        ], isError: true)
                }
                parsed.append(eventType)
            }
            newEventTypes = parsed
        }

        // Fetch current webhook
        let currentResponse = try await client.send(
            Resources.v1.webhooks.id(webhookId).get(
                fieldsWebhooks: [.enabled, .eventTypes, .name, .url]
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
        if let v = newUrl {
            changes["url"] = [
                "old": currentAttrs?.url?.absoluteString ?? "",
                "new": v.absoluteString,
            ]
        }
        if let v = newEnabled {
            changes["enabled"] = [
                "old": currentAttrs?.isEnabled ?? false,
                "new": v,
            ]
        }
        if let v = newEventTypes {
            changes["eventTypes"] = [
                "old": currentAttrs?.eventTypes?.map(\.rawValue) ?? [],
                "new": v.map(\.rawValue),
            ]
        }
        if newSecret != nil {
            changes["secret"] = [
                "old": "***",
                "new": "***",
            ]
        }

        if dryRun {
            let result: [String: Any] = [
                "status": "dry_run",
                "webhookId": webhookId,
                "webhookName": currentAttrs?.name ?? "",
                "changes": changes,
            ]
            let json = try JSONSerialization.data(
                withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            return .init(
                content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        // Apply update
        let updateAttrs = WebhookUpdateRequest.Data.Attributes(
            isEnabled: newEnabled,
            eventTypes: newEventTypes,
            name: newName,
            secret: newSecret,
            url: newUrl
        )

        let request = WebhookUpdateRequest(
            data: .init(
                id: webhookId,
                attributes: updateAttrs
            )
        )

        _ = try await client.send(
            Resources.v1.webhooks.id(webhookId).patch(request)
        )

        let result: [String: Any] = [
            "status": "updated",
            "webhookId": webhookId,
            "changes": changes,
        ]
        let json = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return .init(
            content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
