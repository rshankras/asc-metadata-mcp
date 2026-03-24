import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum CreateSubscriptionGroupTool {
    static let tool = Tool(
        name: "create_subscription_group",
        description: "Create a new subscription group for an app.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "appId": .object(["type": "string", "description": "App Store app ID"]),
                "referenceName": .object([
                    "type": "string",
                    "description": "Reference name for the subscription group",
                ]),
                "dryRun": .object([
                    "type": "boolean",
                    "description":
                        "Preview changes without applying (default: false)",
                    "default": .bool(false),
                ]),
            ]),
            "required": .array([.string("appId"), .string("referenceName")]),
        ])
    )

    static func handle(
        arguments: [String: Value]?,
        client: AppStoreConnectClient
    ) async throws -> CallTool.Result {
        guard let appId = arguments?["appId"]?.stringValue else {
            return .init(content: [.text("Error: appId is required")], isError: true)
        }
        guard let referenceName = arguments?["referenceName"]?.stringValue else {
            return .init(
                content: [.text("Error: referenceName is required")], isError: true)
        }
        let dryRun = arguments?["dryRun"]?.boolValue ?? false

        var resultDict: [String: Any] = [
            "appId": appId,
            "referenceName": referenceName,
        ]

        if dryRun {
            resultDict["status"] = "dry_run"
            let json = try JSONSerialization.data(
                withJSONObject: resultDict,
                options: [.prettyPrinted, .sortedKeys])
            return .init(
                content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        let request = SubscriptionGroupCreateRequest(
            data: .init(
                attributes: .init(referenceName: referenceName),
                relationships: .init(
                    app: .init(data: .init(id: appId))
                )
            )
        )

        let response = try await client.send(
            Resources.v1.subscriptionGroups.post(request)
        )

        resultDict["status"] = "created"
        resultDict["groupId"] = response.data.id

        let json = try JSONSerialization.data(
            withJSONObject: resultDict, options: [.prettyPrinted, .sortedKeys])
        return .init(
            content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
