import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum DeleteCustomPageTool {
    static let tool = Tool(
        name: "delete_custom_page",
        description:
            "Delete a custom product page. Fetches page details before deleting for confirmation.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "pageId": .object([
                    "type": "string",
                    "description": "Custom product page ID to delete",
                ]),
                "dryRun": .object([
                    "type": "boolean",
                    "description":
                        "Preview what will be deleted without deleting (default: false)",
                    "default": .bool(false),
                ]),
            ]),
            "required": .array([.string("pageId")]),
        ])
    )

    static func handle(
        arguments: [String: Value]?,
        client: AppStoreConnectClient
    ) async throws -> CallTool.Result {
        guard let pageId = arguments?["pageId"]?.stringValue else {
            return .init(content: [.text("Error: pageId is required")], isError: true)
        }
        let dryRun = arguments?["dryRun"]?.boolValue ?? false

        // Fetch page details
        let currentResponse = try await client.send(
            Resources.v1.appCustomProductPages.id(pageId).get(
                fieldsAppCustomProductPages: [.name, .url, .visible]
            )
        )
        let page = currentResponse.data
        var pageInfo: [String: Any] = [
            "pageId": page.id,
        ]
        if let name = page.attributes?.name { pageInfo["name"] = name }
        if let url = page.attributes?.url { pageInfo["url"] = url.absoluteString }
        if let visible = page.attributes?.isVisible { pageInfo["visible"] = visible }

        if dryRun {
            let result: [String: Any] = [
                "status": "dry_run",
                "action": "delete",
                "page": pageInfo,
            ]
            let json = try JSONSerialization.data(
                withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            return .init(
                content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        _ = try await client.send(
            Resources.v1.appCustomProductPages.id(pageId).delete
        )

        let result: [String: Any] = [
            "status": "deleted",
            "page": pageInfo,
        ]
        let json = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return .init(
            content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
