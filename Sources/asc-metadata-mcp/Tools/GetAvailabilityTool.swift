import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum GetAvailabilityTool {
    static let tool = Tool(
        name: "get_availability",
        description:
            "Get territory availability for an app, including which territories the app is available in and their status.",
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

        // Get the app availability with territory availabilities included
        let response = try await client.send(
            Resources.v1.apps.id(appId).appAvailabilityV2.get(
                fieldsAppAvailabilities: [.availableInNewTerritories, .territoryAvailabilities],
                fieldsTerritoryAvailabilities: [
                    .available, .releaseDate, .preOrderEnabled, .preOrderPublishDate,
                    .contentStatuses, .territory,
                ],
                include: [.territoryAvailabilities],
                limitTerritoryAvailabilities: 200
            )
        )

        let availability = response.data
        var result: [String: Any] = [
            "availabilityId": availability.id,
            "appId": appId,
            "availableInNewTerritories": availability.attributes?.isAvailableInNewTerritories ?? false,
        ]

        // Process territory availabilities from included
        var territories: [[String: Any]] = []
        var availableCount = 0
        var unavailableCount = 0

        if let included = response.included {
            for ta in included {
                var taDict: [String: Any] = [
                    "territoryAvailabilityId": ta.id,
                ]

                let isAvailable = ta.attributes?.isAvailable ?? false
                taDict["available"] = isAvailable

                if isAvailable {
                    availableCount += 1
                } else {
                    unavailableCount += 1
                }

                if let releaseDate = ta.attributes?.releaseDate {
                    taDict["releaseDate"] = releaseDate
                }
                if let preOrderEnabled = ta.attributes?.isPreOrderEnabled {
                    taDict["preOrderEnabled"] = preOrderEnabled
                }
                if let preOrderPublishDate = ta.attributes?.preOrderPublishDate {
                    taDict["preOrderPublishDate"] = preOrderPublishDate
                }
                if let contentStatuses = ta.attributes?.contentStatuses, !contentStatuses.isEmpty {
                    taDict["contentStatuses"] = contentStatuses.map { $0.rawValue }
                }
                if let territoryId = ta.relationships?.territory?.data?.id {
                    taDict["territory"] = territoryId
                }

                territories.append(taDict)
            }
        }

        // Sort territories alphabetically by territory code
        territories.sort { (a, b) in
            let aTerritory = a["territory"] as? String ?? ""
            let bTerritory = b["territory"] as? String ?? ""
            return aTerritory < bTerritory
        }

        result["summary"] = [
            "totalTerritories": territories.count,
            "available": availableCount,
            "unavailable": unavailableCount,
        ] as [String: Any]
        result["territories"] = territories

        let json = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return .init(content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
