import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum UpdateAppEventTool {
    static let tool = Tool(
        name: "update_app_event",
        description: "Update an existing in-app event's attributes.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "eventId": .object([
                    "type": "string", "description": "In-app event ID",
                ]),
                "referenceName": .object([
                    "type": "string",
                    "description": "Internal reference name",
                ]),
                "badge": .object([
                    "type": "string",
                    "description": "Event badge type",
                    "enum": .array([
                        .string("LIVE_EVENT"), .string("PREMIERE"),
                        .string("CHALLENGE"),
                        .string("COMPETITION"), .string("NEW_SEASON"),
                        .string("MAJOR_UPDATE"),
                        .string("SPECIAL_EVENT"),
                    ]),
                ]),
                "deepLink": .object([
                    "type": "string", "description": "Deep link URL",
                ]),
                "purchaseRequirement": .object([
                    "type": "string",
                    "description": "Purchase requirement",
                    "enum": .array([
                        .string("NO_COST_ASSOCIATED"),
                        .string("IN_APP_PURCHASE"),
                        .string("SUBSCRIPTION"),
                        .string("IN_APP_PURCHASE_AND_SUBSCRIPTION"),
                        .string("IN_APP_PURCHASE_OR_SUBSCRIPTION"),
                    ]),
                ]),
                "primaryLocale": .object([
                    "type": "string", "description": "Primary locale",
                ]),
                "priority": .object([
                    "type": "string",
                    "description": "Event priority",
                    "enum": .array([.string("HIGH"), .string("NORMAL")]),
                ]),
                "purpose": .object([
                    "type": "string",
                    "description": "Event purpose/audience",
                    "enum": .array([
                        .string("APPROPRIATE_FOR_ALL_USERS"),
                        .string("ATTRACT_NEW_USERS"),
                        .string("KEEP_ACTIVE_USERS_INFORMED"),
                        .string("BRING_BACK_LAPSED_USERS"),
                    ]),
                ]),
                "territorySchedules": .object([
                    "type": "string",
                    "description":
                        "JSON array of territory schedules: [{\"territories\":[\"USA\"],\"publishStart\":\"ISO8601\",\"eventStart\":\"ISO8601\",\"eventEnd\":\"ISO8601\"}]",
                ]),
                "dryRun": .object([
                    "type": "boolean",
                    "description":
                        "Preview changes without applying (default: false)",
                    "default": .bool(false),
                ]),
            ]),
            "required": .array([.string("eventId")]),
        ])
    )

    static func handle(
        arguments: [String: Value]?,
        client: AppStoreConnectClient
    ) async throws -> CallTool.Result {
        guard let eventId = arguments?["eventId"]?.stringValue else {
            return .init(
                content: [.text("Error: eventId is required")], isError: true)
        }

        let newReferenceName = arguments?["referenceName"]?.stringValue
        let badgeStr = arguments?["badge"]?.stringValue
        let deepLinkStr = arguments?["deepLink"]?.stringValue
        let purchaseRequirement = arguments?["purchaseRequirement"]?.stringValue
        let primaryLocale = arguments?["primaryLocale"]?.stringValue
        let priorityStr = arguments?["priority"]?.stringValue
        let purposeStr = arguments?["purpose"]?.stringValue
        let schedulesJson = arguments?["territorySchedules"]?.stringValue
        let dryRun = arguments?["dryRun"]?.boolValue ?? false

        // Ensure at least one field is being updated
        guard
            newReferenceName != nil || badgeStr != nil || deepLinkStr != nil
                || purchaseRequirement != nil || primaryLocale != nil
                || priorityStr != nil || purposeStr != nil
                || schedulesJson != nil
        else {
            return .init(
                content: [
                    .text(
                        "Error: At least one field to update must be provided")
                ],
                isError: true)
        }

        // Fetch current event
        let currentResponse = try await client.send(
            Resources.v1.appEvents.id(eventId).get()
        )
        let current = currentResponse.data
        let attrs = current.attributes

        // Build changes dict
        var changes: [String: Any] = [:]

        if let newRef = newReferenceName {
            changes["referenceName"] = [
                "old": attrs?.referenceName ?? "", "new": newRef,
            ]
        }

        // Map badge
        var badge: AppEventUpdateRequest.Data.Attributes.Badge? = nil
        if let badgeStr = badgeStr {
            switch badgeStr {
            case "LIVE_EVENT": badge = .liveEvent
            case "PREMIERE": badge = .premiere
            case "CHALLENGE": badge = .challenge
            case "COMPETITION": badge = .competition
            case "NEW_SEASON": badge = .newSeason
            case "MAJOR_UPDATE": badge = .majorUpdate
            case "SPECIAL_EVENT": badge = .specialEvent
            default:
                return .init(
                    content: [.text("Error: Invalid badge '\(badgeStr)'")],
                    isError: true)
            }
            changes["badge"] = [
                "old": attrs?.badge?.rawValue ?? "", "new": badgeStr,
            ]
        }

        // Map priority
        var priority: AppEventUpdateRequest.Data.Attributes.Priority? = nil
        if let priorityStr = priorityStr {
            switch priorityStr {
            case "HIGH": priority = .high
            case "NORMAL": priority = .normal
            default:
                return .init(
                    content: [
                        .text("Error: Invalid priority '\(priorityStr)'")
                    ],
                    isError: true)
            }
            changes["priority"] = [
                "old": attrs?.priority?.rawValue ?? "", "new": priorityStr,
            ]
        }

        // Map purpose
        var purpose: AppEventUpdateRequest.Data.Attributes.Purpose? = nil
        if let purposeStr = purposeStr {
            switch purposeStr {
            case "APPROPRIATE_FOR_ALL_USERS": purpose = .appropriateForAllUsers
            case "ATTRACT_NEW_USERS": purpose = .attractNewUsers
            case "KEEP_ACTIVE_USERS_INFORMED": purpose = .keepActiveUsersInformed
            case "BRING_BACK_LAPSED_USERS": purpose = .bringBackLapsedUsers
            default:
                return .init(
                    content: [
                        .text("Error: Invalid purpose '\(purposeStr)'")
                    ],
                    isError: true)
            }
            changes["purpose"] = [
                "old": attrs?.purpose?.rawValue ?? "", "new": purposeStr,
            ]
        }

        // Deep link
        var deepLink: URL? = nil
        if let deepLinkStr = deepLinkStr {
            guard let url = URL(string: deepLinkStr) else {
                return .init(
                    content: [
                        .text(
                            "Error: Invalid deep link URL '\(deepLinkStr)'")
                    ],
                    isError: true)
            }
            deepLink = url
            changes["deepLink"] = [
                "old": attrs?.deepLink?.absoluteString ?? "",
                "new": deepLinkStr,
            ]
        }

        if let pr = purchaseRequirement {
            changes["purchaseRequirement"] = [
                "old": attrs?.purchaseRequirement ?? "", "new": pr,
            ]
        }

        if let pl = primaryLocale {
            changes["primaryLocale"] = [
                "old": attrs?.primaryLocale ?? "", "new": pl,
            ]
        }

        // Parse territory schedules
        var territorySchedules:
            [AppEventUpdateRequest.Data.Attributes.TerritorySchedule]? = nil
        if let json = schedulesJson, let data = json.data(using: .utf8) {
            guard
                let arr = try? JSONSerialization.jsonObject(with: data)
                    as? [[String: Any]]
            else {
                return .init(
                    content: [
                        .text("Error: Invalid territorySchedules JSON")
                    ],
                    isError: true)
            }
            territorySchedules = arr.map { dict in
                let territories = dict["territories"] as? [String]
                let publishStart = (dict["publishStart"] as? String).flatMap {
                    parseISO8601($0)
                }
                let eventStart = (dict["eventStart"] as? String).flatMap {
                    parseISO8601($0)
                }
                let eventEnd = (dict["eventEnd"] as? String).flatMap {
                    parseISO8601($0)
                }
                return .init(
                    territories: territories,
                    publishStart: publishStart,
                    eventStart: eventStart,
                    eventEnd: eventEnd
                )
            }
            changes["territorySchedules"] = "updated"
        }

        if dryRun {
            let result: [String: Any] = [
                "status": "dry_run", "eventId": eventId, "changes": changes,
            ]
            let json = try JSONSerialization.data(
                withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            return .init(
                content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        // Apply update
        let updateRequest = AppEventUpdateRequest(
            data: .init(
                id: eventId,
                attributes: .init(
                    referenceName: newReferenceName,
                    badge: badge,
                    deepLink: deepLink,
                    purchaseRequirement: purchaseRequirement,
                    primaryLocale: primaryLocale,
                    priority: priority,
                    purpose: purpose,
                    territorySchedules: territorySchedules
                )
            )
        )

        _ = try await client.send(
            Resources.v1.appEvents.id(eventId).patch(updateRequest)
        )

        let result: [String: Any] = [
            "status": "updated", "eventId": eventId, "changes": changes,
        ]
        let json = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return .init(
            content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }

    private static func parseISO8601(_ str: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: str) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: str)
    }
}
