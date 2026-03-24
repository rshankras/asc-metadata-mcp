import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum ListIAPTool {
    static let tool = Tool(
        name: "list_iap",
        description: "List in-app purchases for an app.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "appId": .object(["type": "string", "description": "App Store app ID"]),
                "filterState": .object([
                    "type": "string",
                    "description": "Filter by in-app purchase state",
                    "enum": .array([
                        .string("MISSING_METADATA"),
                        .string("WAITING_FOR_UPLOAD"),
                        .string("PROCESSING_CONTENT"),
                        .string("READY_TO_SUBMIT"),
                        .string("WAITING_FOR_REVIEW"),
                        .string("IN_REVIEW"),
                        .string("DEVELOPER_ACTION_NEEDED"),
                        .string("PENDING_BINARY_APPROVAL"),
                        .string("APPROVED"),
                        .string("DEVELOPER_REMOVED_FROM_SALE"),
                        .string("REMOVED_FROM_SALE"),
                        .string("REJECTED"),
                    ]),
                ]),
                "filterType": .object([
                    "type": "string",
                    "description": "Filter by in-app purchase type",
                    "enum": .array([
                        .string("CONSUMABLE"),
                        .string("NON_CONSUMABLE"),
                        .string("NON_RENEWING_SUBSCRIPTION"),
                    ]),
                ]),
                "limit": .object([
                    "type": "integer",
                    "description": "Maximum number of results (default: 50)",
                    "default": .int(50),
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
        let filterStateStr = arguments?["filterState"]?.stringValue
        let filterTypeStr = arguments?["filterType"]?.stringValue
        let limit = arguments?["limit"]?.intValue ?? 50

        var filterState: [Resources.V1.Apps.WithID.InAppPurchasesV2.FilterState]? = nil
        if let stateStr = filterStateStr {
            guard let state = Resources.V1.Apps.WithID.InAppPurchasesV2.FilterState(rawValue: stateStr) else {
                return .init(
                    content: [.text("Error: Invalid filterState '\(stateStr)'")],
                    isError: true)
            }
            filterState = [state]
        }

        var filterType: [Resources.V1.Apps.WithID.InAppPurchasesV2.FilterInAppPurchaseType]? = nil
        if let typeStr = filterTypeStr {
            guard let type = Resources.V1.Apps.WithID.InAppPurchasesV2.FilterInAppPurchaseType(rawValue: typeStr) else {
                return .init(
                    content: [.text("Error: Invalid filterType '\(typeStr)'")],
                    isError: true)
            }
            filterType = [type]
        }

        let response = try await client.send(
            Resources.v1.apps.id(appId).inAppPurchasesV2.get(
                filterState: filterState,
                filterInAppPurchaseType: filterType,
                fieldsInAppPurchases: [.name, .productID, .inAppPurchaseType, .state, .reviewNote, .familySharable],
                limit: limit
            )
        )

        var iaps: [[String: Any]] = []

        for iap in response.data {
            let attrs = iap.attributes
            var iapDict: [String: Any] = [
                "id": iap.id,
            ]
            if let name = attrs?.name { iapDict["name"] = name }
            if let productId = attrs?.productID { iapDict["productId"] = productId }
            if let type = attrs?.inAppPurchaseType { iapDict["type"] = type.rawValue }
            if let state = attrs?.state { iapDict["state"] = state.rawValue }
            if let familySharable = attrs?.isFamilySharable {
                iapDict["familySharable"] = familySharable
            }

            iaps.append(iapDict)
        }

        let json = try JSONSerialization.data(
            withJSONObject: iaps, options: [.prettyPrinted, .sortedKeys])
        return .init(content: [.text(String(data: json, encoding: .utf8) ?? "[]")])
    }
}
