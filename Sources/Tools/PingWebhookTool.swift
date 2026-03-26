import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum PingWebhookTool {
    static let tool = Tool(
        name: "ping_webhook",
        description:
            "Send a test ping to a webhook endpoint to verify it's reachable and correctly configured.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "webhookId": .object([
                    "type": "string",
                    "description": "Webhook ID to ping",
                ])
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

        let request = WebhookPingCreateRequest(
            data: .init(
                relationships: .init(
                    webhook: .init(
                        data: .init(id: webhookId)
                    )
                )
            )
        )

        let response = try await client.send(
            Resources.v1.webhookPings.post(request)
        )

        let result: [String: Any] = [
            "status": "ping_sent",
            "pingId": response.data.id,
            "webhookId": webhookId,
        ]
        let json = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return .init(
            content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
