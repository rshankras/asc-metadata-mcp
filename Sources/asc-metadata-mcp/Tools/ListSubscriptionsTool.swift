import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum ListSubscriptionsTool {
    static let tool = Tool(
        name: "list_subscriptions",
        description: "List subscriptions in a subscription group.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "groupId": .object([
                    "type": "string",
                    "description": "Subscription group ID",
                ]),
            ]),
            "required": .array([.string("groupId")]),
        ])
    )

    static func handle(
        arguments: [String: Value]?,
        client: AppStoreConnectClient
    ) async throws -> CallTool.Result {
        guard let groupId = arguments?["groupId"]?.stringValue else {
            return .init(content: [.text("Error: groupId is required")], isError: true)
        }

        let response = try await client.send(
            Resources.v1.subscriptionGroups.id(groupId).subscriptions.get(
                fieldsSubscriptions: [
                    .name, .productID, .state, .subscriptionPeriod,
                    .familySharable, .reviewNote, .groupLevel,
                ]
            )
        )

        var subscriptions: [[String: Any]] = []
        for sub in response.data {
            let attrs = sub.attributes
            var subDict: [String: Any] = [
                "subscriptionId": sub.id,
            ]
            if let name = attrs?.name { subDict["name"] = name }
            if let productID = attrs?.productID { subDict["productId"] = productID }
            if let state = attrs?.state { subDict["state"] = state.rawValue }
            if let period = attrs?.subscriptionPeriod {
                subDict["subscriptionPeriod"] = period.rawValue
            }
            if let familySharable = attrs?.isFamilySharable {
                subDict["familySharable"] = familySharable
            }
            if let reviewNote = attrs?.reviewNote { subDict["reviewNote"] = reviewNote }
            if let groupLevel = attrs?.groupLevel { subDict["groupLevel"] = groupLevel }
            subscriptions.append(subDict)
        }

        let json = try JSONSerialization.data(
            withJSONObject: subscriptions, options: [.prettyPrinted, .sortedKeys])
        return .init(content: [.text(String(data: json, encoding: .utf8) ?? "[]")])
    }
}
