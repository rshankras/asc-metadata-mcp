import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum ListCustomPagesTool {
    static let tool = Tool(
        name: "list_custom_pages",
        description:
            "List all custom product pages for an app with their versions and states.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "appId": .object(["type": "string", "description": "App Store app ID"]),
                "filterVisible": .object([
                    "type": "string",
                    "description": "Filter by visibility (true/false)",
                    "enum": .array([.string("true"), .string("false")]),
                ]),
            ]),
            "required": .array([.string("appId")]),
        ])
    )

    static func handle(
        arguments: [String: Value]?,
        client: AppStoreConnectClient
    ) async throws -> CallTool.Result {
        guard let appId = arguments?["appId"]?.stringValue else {
            return .init(content: [.text("Error: appId is required")], isError: true)
        }
        let filterVisible = arguments?["filterVisible"]?.stringValue

        var visibleFilter: [String]? = nil
        if let v = filterVisible {
            visibleFilter = [v]
        }

        let response = try await client.send(
            Resources.v1.apps.id(appId).appCustomProductPages.get(
                filterVisible: visibleFilter,
                fieldsAppCustomProductPages: [.name, .url, .visible],
                fieldsAppCustomProductPageVersions: [.version, .state, .deepLink],
                include: [.appCustomProductPageVersions]
            )
        )

        var pages: [[String: Any]] = []
        for page in response.data {
            let attrs = page.attributes
            var pageDict: [String: Any] = [
                "pageId": page.id,
            ]
            if let name = attrs?.name { pageDict["name"] = name }
            if let url = attrs?.url { pageDict["url"] = url.absoluteString }
            if let visible = attrs?.isVisible { pageDict["visible"] = visible }

            // Find included versions for this page
            if let versionRels = page.relationships?.appCustomProductPageVersions?.data {
                let versionIds = Set(versionRels.map { $0.id })
                var versionDicts: [[String: Any]] = []
                for item in response.included ?? [] {
                    if case .appCustomProductPageVersion(let version) = item,
                        versionIds.contains(version.id)
                    {
                        var vDict: [String: Any] = ["versionId": version.id]
                        if let state = version.attributes?.state {
                            vDict["state"] = state.rawValue
                        }
                        if let deepLink = version.attributes?.deepLink {
                            vDict["deepLink"] = deepLink.absoluteString
                        }
                        versionDicts.append(vDict)
                    }
                }
                if !versionDicts.isEmpty {
                    pageDict["versions"] = versionDicts
                }
            }

            pages.append(pageDict)
        }

        let result: [String: Any] = [
            "totalPages": pages.count,
            "customProductPages": pages,
        ]
        let json = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return .init(content: [.text(String(data: json, encoding: .utf8) ?? "[]")])
    }
}
