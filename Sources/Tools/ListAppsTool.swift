import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum ListAppsTool {
    static let tool = Tool(
        name: "list_apps",
        description: "List all apps in your App Store Connect account.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([:]),
        ])
    )

    static func handle(
        arguments: [String: Value]?,
        client: AppStoreConnectClient
    ) async throws -> CallTool.Result {
        let response = try await client.send(Resources.v1.apps.get())

        var apps: [[String: String]] = []
        for app in response.data {
            let attrs = app.attributes
            apps.append([
                "appId": app.id,
                "name": attrs?.name ?? "",
                "bundleId": attrs?.bundleID ?? "",
                "sku": attrs?.sku ?? "",
            ])
        }

        let json = try JSONSerialization.data(
            withJSONObject: apps, options: [.prettyPrinted, .sortedKeys])
        let text = String(data: json, encoding: .utf8) ?? "[]"
        return .init(content: [.text(text)])
    }
}
