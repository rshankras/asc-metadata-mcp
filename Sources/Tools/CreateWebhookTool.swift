import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum CreateWebhookTool {
    static let tool = Tool(
        name: "create_webhook",
        description:
            "Create a webhook for an app. Specify URL, secret, and which event types to subscribe to. Supports 12 event types including build uploads, beta feedback, version state changes, and more.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "appId": .object([
                    "type": "string",
                    "description": "App Store app ID",
                ]),
                "name": .object([
                    "type": "string",
                    "description": "Name for the webhook",
                ]),
                "url": .object([
                    "type": "string",
                    "description": "Webhook endpoint URL",
                ]),
                "secret": .object([
                    "type": "string",
                    "description":
                        "Shared secret for HMAC-SHA256 signature verification",
                ]),
                "eventTypes": .object([
                    "type": "array",
                    "description":
                        "Event types to subscribe to",
                    "items": .object([
                        "type": "string",
                        "enum": .array([
                            .string("BUILD_UPLOAD_STATE_UPDATED"),
                            .string("BUILD_BETA_DETAIL_EXTERNAL_BUILD_STATE_UPDATED"),
                            .string("BETA_FEEDBACK_CRASH_SUBMISSION_CREATED"),
                            .string("BETA_FEEDBACK_SCREENSHOT_SUBMISSION_CREATED"),
                            .string("APP_STORE_VERSION_APP_VERSION_STATE_UPDATED"),
                            .string("BACKGROUND_ASSET_VERSION_STATE_UPDATED"),
                            .string("BACKGROUND_ASSET_VERSION_APP_STORE_RELEASE_STATE_UPDATED"),
                            .string("BACKGROUND_ASSET_VERSION_EXTERNAL_BETA_RELEASE_STATE_UPDATED"),
                            .string("BACKGROUND_ASSET_VERSION_INTERNAL_BETA_RELEASE_CREATED"),
                            .string("ALTERNATIVE_DISTRIBUTION_PACKAGE_AVAILABLE_UPDATED"),
                            .string("ALTERNATIVE_DISTRIBUTION_PACKAGE_VERSION_CREATED"),
                            .string("ALTERNATIVE_DISTRIBUTION_TERRITORY_AVAILABILITY_UPDATED"),
                        ]),
                    ]),
                ]),
                "enabled": .object([
                    "type": "boolean",
                    "description": "Whether the webhook is enabled (default: true)",
                    "default": .bool(true),
                ]),
                "dryRun": .object([
                    "type": "boolean",
                    "description":
                        "Preview changes without applying (default: false)",
                    "default": .bool(false),
                ]),
            ]),
            "required": .array([
                .string("appId"), .string("name"), .string("url"),
                .string("secret"), .string("eventTypes"),
            ]),
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
        guard let name = arguments?["name"]?.stringValue else {
            return .init(
                content: [.text("Error: name is required")], isError: true)
        }
        guard let urlStr = arguments?["url"]?.stringValue else {
            return .init(
                content: [.text("Error: url is required")], isError: true)
        }
        guard let secret = arguments?["secret"]?.stringValue else {
            return .init(
                content: [.text("Error: secret is required")], isError: true)
        }
        guard let eventTypeValues = arguments?["eventTypes"]?.arrayValue else {
            return .init(
                content: [.text("Error: eventTypes array is required")],
                isError: true)
        }

        guard let parsedURL = URL(string: urlStr) else {
            return .init(
                content: [.text("Error: Invalid URL '\(urlStr)'")],
                isError: true)
        }

        // Parse event types
        var parsedTypes: [WebhookEventType] = []
        for value in eventTypeValues {
            guard let str = value.stringValue else {
                return .init(
                    content: [
                        .text("Error: eventTypes must be an array of strings")
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
            parsedTypes.append(eventType)
        }

        let enabled = arguments?["enabled"]?.boolValue ?? true
        let dryRun = arguments?["dryRun"]?.boolValue ?? false

        var preview: [String: Any] = [
            "appId": appId,
            "name": name,
            "url": urlStr,
            "eventTypes": parsedTypes.map(\.rawValue),
            "enabled": enabled,
        ]

        if dryRun {
            preview["status"] = "dry_run"
            let json = try JSONSerialization.data(
                withJSONObject: preview,
                options: [.prettyPrinted, .sortedKeys])
            return .init(
                content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        let createAttrs = WebhookCreateRequest.Data.Attributes(
            isEnabled: enabled,
            eventTypes: parsedTypes,
            name: name,
            secret: secret,
            url: parsedURL
        )

        let request = WebhookCreateRequest(
            data: .init(
                attributes: createAttrs,
                relationships: .init(
                    app: .init(data: .init(id: appId))
                )
            )
        )

        let response = try await client.send(
            Resources.v1.webhooks.post(request)
        )

        let created = response.data
        var resultDict: [String: Any] = [
            "status": "created",
            "webhookId": created.id,
            "name": created.attributes?.name ?? name,
            "appId": appId,
        ]
        if let url = created.attributes?.url {
            resultDict["url"] = url.absoluteString
        }
        if let v = created.attributes?.isEnabled {
            resultDict["enabled"] = v
        }
        if let eventTypes = created.attributes?.eventTypes {
            resultDict["eventTypes"] = eventTypes.map(\.rawValue)
        }

        let json = try JSONSerialization.data(
            withJSONObject: resultDict, options: [.prettyPrinted, .sortedKeys])
        return .init(
            content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
