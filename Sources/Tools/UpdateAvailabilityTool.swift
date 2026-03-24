import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum UpdateAvailabilityTool {
    static let tool = Tool(
        name: "update_availability",
        description:
            "Update territory availability for an app. Can toggle whether the app is automatically available in new territories, and enable/disable availability in specific territories.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "appId": .object([
                    "type": "string", "description": "App Store app ID",
                ]),
                "availableInNewTerritories": .object([
                    "type": "boolean",
                    "description":
                        "Whether the app should automatically become available in new App Store territories",
                ]),
                "addTerritories": .object([
                    "type": "string",
                    "description":
                        "Comma-separated territory codes to make available (e.g. 'USA,GBR,JPN'). Uses territory availability IDs internally.",
                ]),
                "removeTerritories": .object([
                    "type": "string",
                    "description":
                        "Comma-separated territory codes to make unavailable (e.g. 'CHN,RUS'). Uses territory availability IDs internally.",
                ]),
                "dryRun": .object([
                    "type": "boolean",
                    "description":
                        "Preview changes without applying (default: false)",
                    "default": .bool(false),
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

        let availableInNewTerritories = arguments?["availableInNewTerritories"]?.boolValue
        let addTerritoriesStr = arguments?["addTerritories"]?.stringValue
        let removeTerritoriesStr = arguments?["removeTerritories"]?.stringValue
        let dryRun = arguments?["dryRun"]?.boolValue ?? false

        // Ensure at least one change is requested
        guard
            availableInNewTerritories != nil || addTerritoriesStr != nil
                || removeTerritoriesStr != nil
        else {
            return .init(
                content: [
                    .text(
                        "Error: At least one of availableInNewTerritories, addTerritories, or removeTerritories must be provided"
                    )
                ],
                isError: true)
        }

        let addTerritories = addTerritoriesStr?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty } ?? []

        let removeTerritories = removeTerritoriesStr?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty } ?? []

        // Fetch current availability
        let currentResponse = try await client.send(
            Resources.v1.apps.id(appId).appAvailabilityV2.get(
                fieldsAppAvailabilities: [.availableInNewTerritories, .territoryAvailabilities],
                fieldsTerritoryAvailabilities: [
                    .available, .releaseDate, .preOrderEnabled, .contentStatuses, .territory,
                ],
                include: [.territoryAvailabilities],
                limitTerritoryAvailabilities: 200
            )
        )

        let currentAvailability = currentResponse.data
        let currentAvailableInNew =
            currentAvailability.attributes?.isAvailableInNewTerritories ?? false

        // Build territory code -> TerritoryAvailability mapping from included
        var territoryCodeToAvailability: [String: (id: String, available: Bool)] = [:]
        if let included = currentResponse.included {
            for ta in included {
                if let territoryId = ta.relationships?.territory?.data?.id {
                    territoryCodeToAvailability[territoryId] = (
                        id: ta.id,
                        available: ta.attributes?.isAvailable ?? false
                    )
                }
            }
        }

        // Build changes summary
        var changes: [String: Any] = [:]

        if let newValue = availableInNewTerritories {
            changes["availableInNewTerritories"] = [
                "old": currentAvailableInNew,
                "new": newValue,
            ] as [String: Any]
        }

        // Validate and summarize territory changes
        var territoriesToEnable: [(code: String, availabilityId: String)] = []
        var territoriesToDisable: [(code: String, availabilityId: String)] = []

        for code in addTerritories {
            guard let ta = territoryCodeToAvailability[code] else {
                return .init(
                    content: [
                        .text(
                            "Error: Territory '\(code)' not found. Use get_availability to see valid territory codes."
                        )
                    ],
                    isError: true)
            }
            if !ta.available {
                territoriesToEnable.append((code: code, availabilityId: ta.id))
            }
        }

        for code in removeTerritories {
            guard let ta = territoryCodeToAvailability[code] else {
                return .init(
                    content: [
                        .text(
                            "Error: Territory '\(code)' not found. Use get_availability to see valid territory codes."
                        )
                    ],
                    isError: true)
            }
            if ta.available {
                territoriesToDisable.append((code: code, availabilityId: ta.id))
            }
        }

        if !territoriesToEnable.isEmpty {
            changes["enableTerritories"] = territoriesToEnable.map { $0.code }
        }
        if !territoriesToDisable.isEmpty {
            changes["disableTerritories"] = territoriesToDisable.map { $0.code }
        }

        if changes.isEmpty {
            let result: [String: Any] = [
                "status": "no_changes",
                "message": "All specified territories already have the requested availability state.",
            ]
            let json = try JSONSerialization.data(
                withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            return .init(content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        if dryRun {
            let result: [String: Any] = [
                "status": "dry_run",
                "appId": appId,
                "changes": changes,
            ]
            let json = try JSONSerialization.data(
                withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            return .init(content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        // Apply territory availability changes via PATCH on individual territory availabilities
        var updatedTerritories: [String] = []

        for item in territoriesToEnable {
            let updateRequest = TerritoryAvailabilityUpdateRequest(
                data: .init(
                    id: item.availabilityId,
                    attributes: .init(isAvailable: true)
                )
            )
            _ = try await client.send(
                Resources.v1.territoryAvailabilities.id(item.availabilityId)
                    .patch(updateRequest)
            )
            updatedTerritories.append("\(item.code): enabled")
        }

        for item in territoriesToDisable {
            let updateRequest = TerritoryAvailabilityUpdateRequest(
                data: .init(
                    id: item.availabilityId,
                    attributes: .init(isAvailable: false)
                )
            )
            _ = try await client.send(
                Resources.v1.territoryAvailabilities.id(item.availabilityId)
                    .patch(updateRequest)
            )
            updatedTerritories.append("\(item.code): disabled")
        }

        // Handle availableInNewTerritories via creating a new availability (POST replaces current)
        if let newValue = availableInNewTerritories, newValue != currentAvailableInNew {
            // Re-fetch current territory availabilities for the create request
            let refreshed = try await client.send(
                Resources.v1.apps.id(appId).appAvailabilityV2.get(
                    fieldsAppAvailabilities: [.territoryAvailabilities],
                    fieldsTerritoryAvailabilities: [.available, .territory],
                    include: [.territoryAvailabilities],
                    limitTerritoryAvailabilities: 200
                )
            )

            // Build territory availability references for the create request
            var taData: [AppAvailabilityV2CreateRequest.Data.Relationships.TerritoryAvailabilities.Datum] = []
            var taInlineCreates: [TerritoryAvailabilityInlineCreate] = []

            if let included = refreshed.included {
                for ta in included {
                    taData.append(.init(id: ta.id))
                    taInlineCreates.append(.init(id: ta.id))
                }
            }

            let createRequest = AppAvailabilityV2CreateRequest(
                data: .init(
                    attributes: .init(isAvailableInNewTerritories: newValue),
                    relationships: .init(
                        app: .init(data: .init(id: appId)),
                        territoryAvailabilities: .init(data: taData)
                    )
                ),
                included: taInlineCreates
            )

            _ = try await client.send(
                Resources.v2.appAvailabilities.post(createRequest)
            )
        }

        var result: [String: Any] = [
            "status": "updated",
            "appId": appId,
            "changes": changes,
        ]
        if !updatedTerritories.isEmpty {
            result["updatedTerritories"] = updatedTerritories
        }

        let json = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return .init(content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
