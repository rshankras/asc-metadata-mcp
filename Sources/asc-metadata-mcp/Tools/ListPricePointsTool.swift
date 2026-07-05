import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum ListPricePointsTool {
    static let tool = Tool(
        name: "list_price_points",
        description:
            "List available price points (tiers) for an app in a specific territory. Shows customer price and developer proceeds for each tier.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "appId": .object([
                    "type": "string", "description": "App Store app ID",
                ]),
                "territory": .object([
                    "type": "string",
                    "description":
                        "Territory code to filter by (e.g. 'USA', 'GBR', 'JPN'). If omitted, returns price points for all territories.",
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
        let territory = arguments?["territory"]?.stringValue

        let filterTerritory: [String]? = territory != nil ? [territory!] : nil

        let response = try await client.send(
            Resources.v1.apps.id(appId).appPricePoints.get(
                filterTerritory: filterTerritory,
                fieldsAppPricePoints: [.customerPrice, .proceeds, .territory],
                fieldsTerritories: [.currency],
                limit: 200,
                include: [.territory]
            )
        )

        // Build territory lookup from included
        var territoryMap: [String: (id: String, currency: String)] = [:]
        if let included = response.included {
            for item in included {
                if case .territory(let t) = item {
                    territoryMap[t.id] = (id: t.id, currency: t.attributes?.currency ?? "")
                }
            }
        }

        var pricePoints: [[String: Any]] = []
        for pp in response.data {
            var ppDict: [String: Any] = [
                "pricePointId": pp.id,
            ]
            if let customerPrice = pp.attributes?.customerPrice {
                ppDict["customerPrice"] = customerPrice
            }
            if let proceeds = pp.attributes?.proceeds {
                ppDict["proceeds"] = proceeds
            }
            if let tId = pp.relationships?.territory?.data?.id {
                ppDict["territory"] = tId
                if let t = territoryMap[tId] {
                    ppDict["currency"] = t.currency
                }
            }
            pricePoints.append(ppDict)
        }

        let result: [String: Any] = [
            "appId": appId,
            "territory": territory ?? "all",
            "count": pricePoints.count,
            "pricePoints": pricePoints,
        ]

        let json = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return .init(content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
