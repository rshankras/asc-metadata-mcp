import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum GetAppPricingTool {
    static let tool = Tool(
        name: "get_app_pricing",
        description:
            "Get the current pricing schedule for an app, including base territory, manual prices, and automatic prices.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "appId": .object([
                    "type": "string", "description": "App Store app ID",
                ])
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

        // Get the price schedule with all includes
        let scheduleResponse = try await client.send(
            Resources.v1.apps.id(appId).appPriceSchedule.get(
                fieldsAppPriceSchedules: [.baseTerritory, .manualPrices, .automaticPrices],
                fieldsTerritories: [.currency],
                fieldsAppPrices: [.manual, .startDate, .endDate, .appPricePoint, .territory],
                include: [.baseTerritory, .manualPrices, .automaticPrices],
                limitManualPrices: 50,
                limitAutomaticPrices: 50
            )
        )

        let schedule = scheduleResponse.data
        var result: [String: Any] = [
            "scheduleId": schedule.id,
            "appId": appId,
        ]

        // Extract base territory from included items
        if let included = scheduleResponse.included {
            // Find base territory
            let baseTerritoryId = schedule.relationships?.baseTerritory?.data?.id
            for item in included {
                if case .territory(let territory) = item, territory.id == baseTerritoryId {
                    result["baseTerritory"] = [
                        "id": territory.id,
                        "currency": territory.attributes?.currency ?? "",
                    ] as [String: Any]
                    break
                }
            }

            // Collect manual prices (developer-set prices)
            var manualPrices: [[String: Any]] = []
            var automaticPrices: [[String: Any]] = []

            // Build lookup maps for price points and territories from included
            var territoryMap: [String: [String: Any]] = [:]

            for item in included {
                switch item {
                case .territory(let territory):
                    territoryMap[territory.id] = [
                        "id": territory.id,
                        "currency": territory.attributes?.currency ?? "",
                    ]
                case .appPriceV2(let price):
                    var priceDict: [String: Any] = [
                        "priceId": price.id,
                        "manual": price.attributes?.isManual ?? false,
                    ]
                    if let startDate = price.attributes?.startDate {
                        priceDict["startDate"] = startDate
                    }
                    if let endDate = price.attributes?.endDate {
                        priceDict["endDate"] = endDate
                    }
                    if let territoryId = price.relationships?.territory?.data?.id {
                        priceDict["territoryId"] = territoryId
                    }
                    if let pricePointId = price.relationships?.appPricePoint?.data?.id {
                        priceDict["pricePointId"] = pricePointId
                    }

                    if price.attributes?.isManual == true {
                        manualPrices.append(priceDict)
                    } else {
                        automaticPrices.append(priceDict)
                    }
                case .app:
                    break
                }
            }

            if !manualPrices.isEmpty {
                result["manualPrices"] = manualPrices
            }
            if !automaticPrices.isEmpty {
                result["automaticPrices"] = automaticPrices
            }
        }

        // Also fetch manual prices with full price point details for richer output
        let manualPricesResponse = try await client.send(
            Resources.v1.appPriceSchedules.id(schedule.id).manualPrices.get(
                fieldsAppPrices: [.manual, .startDate, .endDate, .appPricePoint, .territory],
                fieldsAppPricePoints: [.customerPrice, .proceeds],
                fieldsTerritories: [.currency],
                limit: 50,
                include: [.appPricePoint, .territory]
            )
        )

        var detailedPrices: [[String: Any]] = []
        // Build lookup from included
        var ppMap: [String: (customerPrice: String, proceeds: String)] = [:]
        var tMap: [String: (id: String, currency: String)] = [:]

        if let included = manualPricesResponse.included {
            for item in included {
                switch item {
                case .appPricePointV3(let pp):
                    ppMap[pp.id] = (
                        customerPrice: pp.attributes?.customerPrice ?? "",
                        proceeds: pp.attributes?.proceeds ?? ""
                    )
                case .territory(let t):
                    tMap[t.id] = (id: t.id, currency: t.attributes?.currency ?? "")
                }
            }
        }

        for price in manualPricesResponse.data {
            var priceDict: [String: Any] = [
                "priceId": price.id,
            ]
            if let startDate = price.attributes?.startDate {
                priceDict["startDate"] = startDate
            }
            if let endDate = price.attributes?.endDate {
                priceDict["endDate"] = endDate
            }
            if let ppId = price.relationships?.appPricePoint?.data?.id,
               let pp = ppMap[ppId] {
                priceDict["customerPrice"] = pp.customerPrice
                priceDict["proceeds"] = pp.proceeds
            }
            if let tId = price.relationships?.territory?.data?.id,
               let t = tMap[tId] {
                priceDict["territory"] = t.id
                priceDict["currency"] = t.currency
            }
            detailedPrices.append(priceDict)
        }

        if !detailedPrices.isEmpty {
            result["priceDetails"] = detailedPrices
        }

        let json = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return .init(content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
