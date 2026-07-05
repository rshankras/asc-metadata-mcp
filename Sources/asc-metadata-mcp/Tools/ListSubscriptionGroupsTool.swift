import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum ListSubscriptionGroupsTool {
    static let tool = Tool(
        name: "list_subscription_groups",
        description: "List subscription groups for an app.",
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

        let response = try await client.send(
            Resources.v1.apps.id(appId).subscriptionGroups.get(
                fieldsSubscriptionGroups: [.referenceName],
                fieldsSubscriptions: [.name, .productID, .state, .subscriptionPeriod],
                include: [.subscriptions]
            )
        )

        // Build a map of group ID → subscriptions from included items
        var subscriptionsByGroup: [String: [[String: Any]]] = [:]
        if let included = response.included {
            for item in included {
                if case .subscription(let sub) = item {
                    let groupId = sub.relationships?.group?.data?.id
                    if let groupId = groupId {
                        var subDict: [String: Any] = [
                            "subscriptionId": sub.id,
                        ]
                        if let name = sub.attributes?.name { subDict["name"] = name }
                        if let productID = sub.attributes?.productID {
                            subDict["productId"] = productID
                        }
                        if let state = sub.attributes?.state {
                            subDict["state"] = state.rawValue
                        }
                        if let period = sub.attributes?.subscriptionPeriod {
                            subDict["subscriptionPeriod"] = period.rawValue
                        }
                        subscriptionsByGroup[groupId, default: []].append(subDict)
                    }
                }
            }
        }

        var groups: [[String: Any]] = []
        for group in response.data {
            var groupDict: [String: Any] = [
                "groupId": group.id,
                "referenceName": group.attributes?.referenceName ?? "",
            ]
            if let subs = subscriptionsByGroup[group.id], !subs.isEmpty {
                groupDict["subscriptions"] = subs
            }
            groups.append(groupDict)
        }

        let json = try JSONSerialization.data(
            withJSONObject: groups, options: [.prettyPrinted, .sortedKeys])
        return .init(content: [.text(String(data: json, encoding: .utf8) ?? "[]")])
    }
}
