import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum ListLocalesTool {
    static let tool = Tool(
        name: "list_locales",
        description: "List all active localizations for an app, showing locale codes and localized names.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "appId": .object(["type": "string", "description": "App Store app ID"]),
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

        // Prefer the editable AppInfo so locales reflect the prepared version's set when one
        // exists (locales can be added/removed between versions). See AppInfoSelector.
        let appInfosResponse = try await client.send(
            Resources.v1.apps.id(appId).appInfos.get()
        )
        guard let appInfo = AppInfoSelector.findPreferredOrFirst(in: appInfosResponse.data) else {
            return .init(content: [.text("Error: No app info found for app \(appId)")], isError: true)
        }

        let infoLocsResponse = try await client.send(
            Resources.v1.appInfos.id(appInfo.id).appInfoLocalizations.get()
        )

        var locales: [[String: String]] = []
        for loc in infoLocsResponse.data {
            locales.append([
                "locale": loc.attributes?.locale ?? "",
                "name": loc.attributes?.name ?? "",
            ])
        }

        let result: [String: Any] = [
            "appId": appId,
            "locales": locales,
        ]
        let json = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return .init(content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
