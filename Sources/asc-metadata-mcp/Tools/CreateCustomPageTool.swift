import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum CreateCustomPageTool {
    static let tool = Tool(
        name: "create_custom_page",
        description:
            "Create a new custom product page for an app.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "appId": .object(["type": "string", "description": "App Store app ID"]),
                "name": .object([
                    "type": "string",
                    "description": "Name for the custom product page",
                ]),
                "dryRun": .object([
                    "type": "boolean",
                    "description":
                        "Preview changes without applying (default: false)",
                    "default": .bool(false),
                ]),
            ]),
            "required": .array([.string("appId"), .string("name")]),
        ])
    )

    static func handle(
        arguments: [String: Value]?,
        client: AppStoreConnectClient
    ) async throws -> CallTool.Result {
        guard let appId = arguments?["appId"]?.stringValue else {
            return .init(content: [.text("Error: appId is required")], isError: true)
        }
        guard let name = arguments?["name"]?.stringValue else {
            return .init(content: [.text("Error: name is required")], isError: true)
        }
        let dryRun = arguments?["dryRun"]?.boolValue ?? false

        var resultDict: [String: Any] = [
            "appId": appId,
            "name": name,
        ]

        if dryRun {
            resultDict["status"] = "dry_run"
            let json = try JSONSerialization.data(
                withJSONObject: resultDict, options: [.prettyPrinted, .sortedKeys])
            return .init(
                content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        let request = AppCustomProductPageCreateRequest(
            data: .init(
                attributes: .init(name: name),
                relationships: .init(
                    app: .init(data: .init(id: appId))
                )
            )
        )

        let response = try await client.send(
            Resources.v1.appCustomProductPages.post(request)
        )

        resultDict["status"] = "created"
        resultDict["pageId"] = response.data.id
        if let url = response.data.attributes?.url {
            resultDict["url"] = url.absoluteString
        }

        let json = try JSONSerialization.data(
            withJSONObject: resultDict, options: [.prettyPrinted, .sortedKeys])
        return .init(
            content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
