import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum GetIAPTool {
    static let tool = Tool(
        name: "get_iap",
        description:
            "Get detailed info for an in-app purchase including its attributes.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "iapId": .object([
                    "type": "string",
                    "description": "In-app purchase ID",
                ]),
            ]),
            "required": .array([.string("iapId")]),
        ])
    )

    static func handle(
        arguments: [String: Value]?,
        client: AppStoreConnectClient
    ) async throws -> CallTool.Result {
        guard let iapId = arguments?["iapId"]?.stringValue else {
            return .init(content: [.text("Error: iapId is required")], isError: true)
        }

        let response = try await client.send(
            Resources.v2.inAppPurchases.id(iapId).get(
                fieldsInAppPurchases: [.name, .productID, .inAppPurchaseType, .state, .reviewNote, .familySharable, .contentHosting]
            )
        )

        let iap = response.data
        let attrs = iap.attributes
        var result: [String: Any] = [
            "id": iap.id,
        ]
        if let name = attrs?.name { result["name"] = name }
        if let productId = attrs?.productID { result["productId"] = productId }
        if let type = attrs?.inAppPurchaseType { result["type"] = type.rawValue }
        if let state = attrs?.state { result["state"] = state.rawValue }
        if let reviewNote = attrs?.reviewNote { result["reviewNote"] = reviewNote }
        if let familySharable = attrs?.isFamilySharable {
            result["familySharable"] = familySharable
        }
        if let contentHosting = attrs?.isContentHosting {
            result["contentHosting"] = contentHosting
        }

        let json = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return .init(content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
