import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum CreateIAPTool {
    static let tool = Tool(
        name: "create_iap",
        description: "Create a new in-app purchase.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "appId": .object(["type": "string", "description": "App Store app ID"]),
                "name": .object([
                    "type": "string",
                    "description": "Reference name for the in-app purchase",
                ]),
                "productId": .object([
                    "type": "string",
                    "description": "Product ID (e.g. com.example.app.coins100)",
                ]),
                "inAppPurchaseType": .object([
                    "type": "string",
                    "description": "Type of in-app purchase",
                    "enum": .array([
                        .string("CONSUMABLE"),
                        .string("NON_CONSUMABLE"),
                        .string("NON_RENEWING_SUBSCRIPTION"),
                    ]),
                ]),
                "reviewNote": .object([
                    "type": "string",
                    "description": "Notes for App Review",
                ]),
                "familySharable": .object([
                    "type": "boolean",
                    "description": "Whether this IAP is available via Family Sharing",
                ]),
                "dryRun": .object([
                    "type": "boolean",
                    "description":
                        "Preview changes without applying (default: false)",
                    "default": .bool(false),
                ]),
            ]),
            "required": .array([
                .string("appId"), .string("name"), .string("productId"),
                .string("inAppPurchaseType"),
            ]),
        ])
    )

    static func handle(
        arguments: [String: Value]?,
        client: AppStoreConnectClient
    ) async throws -> CallTool.Result {
        guard let appId = arguments?["appId"]?.stringValue else {
            return .init(content: [.text("Error: appId is required")], isError: true)
        }
        guard let name = arguments?["name"]?.stringValue else {
            return .init(content: [.text("Error: name is required")], isError: true)
        }
        guard let productId = arguments?["productId"]?.stringValue else {
            return .init(
                content: [.text("Error: productId is required")], isError: true)
        }
        guard let typeStr = arguments?["inAppPurchaseType"]?.stringValue else {
            return .init(
                content: [.text("Error: inAppPurchaseType is required")],
                isError: true)
        }

        let reviewNote = arguments?["reviewNote"]?.stringValue
        let familySharable = arguments?["familySharable"]?.boolValue
        let dryRun = arguments?["dryRun"]?.boolValue ?? false

        // Map inAppPurchaseType
        guard let iapType = InAppPurchaseType(rawValue: typeStr) else {
            return .init(
                content: [.text("Error: Invalid inAppPurchaseType '\(typeStr)'")],
                isError: true)
        }

        // Build result preview
        var resultDict: [String: Any] = [
            "appId": appId,
            "name": name,
            "productId": productId,
            "inAppPurchaseType": typeStr,
        ]
        if let rn = reviewNote { resultDict["reviewNote"] = rn }
        if let fs = familySharable { resultDict["familySharable"] = fs }

        if dryRun {
            resultDict["status"] = "dry_run"
            let json = try JSONSerialization.data(
                withJSONObject: resultDict,
                options: [.prettyPrinted, .sortedKeys])
            return .init(
                content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        // Create the in-app purchase
        let request = InAppPurchaseV2CreateRequest(
            data: .init(
                attributes: .init(
                    name: name,
                    productID: productId,
                    inAppPurchaseType: iapType,
                    reviewNote: reviewNote,
                    isFamilySharable: familySharable
                ),
                relationships: .init(
                    app: .init(data: .init(id: appId))
                )
            )
        )

        let response = try await client.send(
            Resources.v2.inAppPurchases.post(request)
        )
        let created = response.data
        resultDict["status"] = "created"
        resultDict["iapId"] = created.id

        let json = try JSONSerialization.data(
            withJSONObject: resultDict, options: [.prettyPrinted, .sortedKeys])
        return .init(
            content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
