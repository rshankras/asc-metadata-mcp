import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum CreateCustomPageVersionTool {
    static let tool = Tool(
        name: "create_custom_page_version",
        description:
            "Create a new version of a custom product page. Required before updating localized content for a new submission.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "pageId": .object([
                    "type": "string",
                    "description": "Custom product page ID",
                ]),
                "deepLink": .object([
                    "type": "string",
                    "description": "Deep link URL for this version (optional)",
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
        let deepLinkStr = arguments?["deepLink"]?.stringValue
        let dryRun = arguments?["dryRun"]?.boolValue ?? false

        var deepLink: URL? = nil
        if let str = deepLinkStr {
            guard let url = URL(string: str) else {
                return .init(
                    content: [.text("Error: Invalid deep link URL '\(str)'")],
                    isError: true)
            }
            deepLink = url
        }

        var resultDict: [String: Any] = [
            "pageId": pageId,
        ]
        if let dl = deepLinkStr { resultDict["deepLink"] = dl }

        if dryRun {
            resultDict["status"] = "dry_run"
            let json = try JSONSerialization.data(
                withJSONObject: resultDict, options: [.prettyPrinted, .sortedKeys])
            return .init(
                content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        var attributes: AppCustomProductPageVersionCreateRequest.Data.Attributes? = nil
        if deepLink != nil {
            attributes = .init(deepLink: deepLink)
        }

        let request = AppCustomProductPageVersionCreateRequest(
            data: .init(
                attributes: attributes,
                relationships: .init(
                    appCustomProductPage: .init(data: .init(id: pageId))
                )
            )
        )

        let response = try await client.send(
            Resources.v1.appCustomProductPageVersions.post(request)
        )

        resultDict["status"] = "created"
        resultDict["versionId"] = response.data.id
        if let state = response.data.attributes?.state {
            resultDict["state"] = state.rawValue
        }

        let json = try JSONSerialization.data(
            withJSONObject: resultDict, options: [.prettyPrinted, .sortedKeys])
        return .init(
            content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
