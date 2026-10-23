import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum DeleteIAPTool {
    static let tool = Tool(
        name: "delete_iap",
        description:
            "Delete an in-app purchase. Fetches details before deleting for confirmation.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "iapId": .object([
                    "type": "string",
                    "description": "In-app purchase ID to delete",
                ]),
                "dryRun": .object([
                    "type": "boolean",
                    "description":
                        "Preview what will be deleted without deleting (default: false)",
                    "default": .bool(false),
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
            return .init(
                content: [.text("Error: iapId is required")], isError: true)
        }
        let dryRun = arguments?["dryRun"]?.boolValue ?? false

        // Fetch the IAP to show what's being deleted
        let currentResponse = try await client.send(
            Resources.v2.inAppPurchases.id(iapId).get()
        )
        let iap = currentResponse.data
        let attrs = iap.attributes

        var iapInfo: [String: Any] = [
            "iapId": iap.id,
        ]
        if let name = attrs?.name { iapInfo["name"] = name }
        if let productId = attrs?.productID { iapInfo["productId"] = productId }
        if let type = attrs?.inAppPurchaseType { iapInfo["type"] = type.rawValue }
        if let state = attrs?.state { iapInfo["state"] = state.rawValue }
        if let reviewNote = attrs?.reviewNote { iapInfo["reviewNote"] = reviewNote }
        if let familySharable = attrs?.isFamilySharable {
            iapInfo["familySharable"] = familySharable
        }

        if dryRun {
            let result: [String: Any] = [
                "status": "dry_run",
                "action": "delete",
                "inAppPurchase": iapInfo,
            ]
            let json = try JSONSerialization.data(
                withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            return .init(
                content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        // Delete the in-app purchase
        _ = try await client.send(Resources.v2.inAppPurchases.id(iapId).delete)

        let result: [String: Any] = [
            "status": "deleted",
            "inAppPurchase": iapInfo,
        ]
        let json = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return .init(
            content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
