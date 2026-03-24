import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum UpdateCustomPageTool {
    static let tool = Tool(
        name: "update_custom_page",
        description:
            "Update a custom product page's name or visibility. Shows old/new diff.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "pageId": .object([
                    "type": "string",
                    "description": "Custom product page ID",
                ]),
                "name": .object([
                    "type": "string",
                    "description": "New name for the custom product page",
                ]),
                "visible": .object([
                    "type": "boolean",
                    "description": "Set visibility of the custom product page",
                ]),
                "dryRun": .object([
                    "type": "boolean",
                    "description":
                        "Preview changes without applying (default: false)",
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
        let newName = arguments?["name"]?.stringValue
        let newVisible = arguments?["visible"]?.boolValue
        let dryRun = arguments?["dryRun"]?.boolValue ?? false

        if newName == nil && newVisible == nil {
            return .init(
                content: [.text("Error: At least one of name or visible must be provided")],
                isError: true)
        }

        // Fetch current state
        let currentResponse = try await client.send(
            Resources.v1.appCustomProductPages.id(pageId).get(
                fieldsAppCustomProductPages: [.name, .url, .visible]
            )
        )
        let current = currentResponse.data
        let currentAttrs = current.attributes

        var oldValues: [String: Any] = [:]
        var newValues: [String: Any] = [:]

        if let newName = newName {
            oldValues["name"] = currentAttrs?.name ?? ""
            newValues["name"] = newName
        }
        if let newVisible = newVisible {
            oldValues["visible"] = currentAttrs?.isVisible ?? false
            newValues["visible"] = newVisible
        }

        var resultDict: [String: Any] = [
            "pageId": pageId,
            "old": oldValues,
            "new": newValues,
        ]

        if dryRun {
            resultDict["status"] = "dry_run"
            let json = try JSONSerialization.data(
                withJSONObject: resultDict, options: [.prettyPrinted, .sortedKeys])
            return .init(
                content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        let request = AppCustomProductPageUpdateRequest(
            data: .init(
                id: pageId,
                attributes: .init(
                    name: newName,
                    isVisible: newVisible
                )
            )
        )

        let response = try await client.send(
            Resources.v1.appCustomProductPages.id(pageId).patch(request)
        )

        resultDict["status"] = "updated"
        if let url = response.data.attributes?.url {
            resultDict["url"] = url.absoluteString
        }

        let json = try JSONSerialization.data(
            withJSONObject: resultDict, options: [.prettyPrinted, .sortedKeys])
        return .init(
            content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
