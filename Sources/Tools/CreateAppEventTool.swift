import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum CreateAppEventTool {
    static let tool = Tool(
        name: "create_app_event",
        description:
            "Create a new in-app event for an app. Optionally creates an initial localization in the same call.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "appId": .object(["type": "string", "description": "App Store app ID"]),
                "referenceName": .object([
                    "type": "string",
                    "description": "Internal reference name for the event",
                ]),
                "badge": .object([
                    "type": "string",
                    "description": "Event badge type",
                    "enum": .array([
                        .string("LIVE_EVENT"), .string("PREMIERE"), .string("CHALLENGE"),
                        .string("COMPETITION"), .string("NEW_SEASON"),
                        .string("MAJOR_UPDATE"),
                        .string("SPECIAL_EVENT"),
                    ]),
                ]),
                "deepLink": .object([
                    "type": "string", "description": "Deep link URL for the event",
                ]),
                "purchaseRequirement": .object([
                    "type": "string",
                    "description": "Purchase requirement",
                    "enum": .array([
                        .string("NO_COST_ASSOCIATED"), .string("IN_APP_PURCHASE"),
                        .string("SUBSCRIPTION"),
                        .string("IN_APP_PURCHASE_AND_SUBSCRIPTION"),
                        .string("IN_APP_PURCHASE_OR_SUBSCRIPTION"),
                    ]),
                ]),
                "primaryLocale": .object([
                    "type": "string",
                    "description": "Primary locale (e.g. en-US)",
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
                "locale": .object([
                    "type": "string",
                    "description":
                        "Locale for initial localization (e.g. en-US). If provided, creates a localization with the event.",
                ]),
                "name": .object([
                    "type": "string",
                    "description": "Event name for localization (max 30 chars)",
                ]),
                "shortDescription": .object([
                    "type": "string",
                    "description":
                        "Short description for localization (max 50 chars)",
                ]),
                "longDescription": .object([
                    "type": "string",
                    "description":
                        "Long description for localization (max 120 chars)",
                ]),
                "dryRun": .object([
                    "type": "boolean",
                    "description":
                        "Preview changes without applying (default: false)",
                    "default": .bool(false),
                ]),
            ]),
            "required": .array([.string("appId"), .string("referenceName")]),
        ])
    )

    static func handle(
        arguments: [String: Value]?,
        client: AppStoreConnectClient
    ) async throws -> CallTool.Result {
        guard let appId = arguments?["appId"]?.stringValue else {
            return .init(content: [.text("Error: appId is required")], isError: true)
        }
        guard let referenceName = arguments?["referenceName"]?.stringValue else {
            return .init(
                content: [.text("Error: referenceName is required")], isError: true)
        }

        let badgeStr = arguments?["badge"]?.stringValue
        let deepLinkStr = arguments?["deepLink"]?.stringValue
        let purchaseRequirement = arguments?["purchaseRequirement"]?.stringValue
        let primaryLocale = arguments?["primaryLocale"]?.stringValue
        let priorityStr = arguments?["priority"]?.stringValue
        let purposeStr = arguments?["purpose"]?.stringValue
        let schedulesJson = arguments?["territorySchedules"]?.stringValue
        let locale = arguments?["locale"]?.stringValue
        let name = arguments?["name"]?.stringValue
        let shortDescription = arguments?["shortDescription"]?.stringValue
        let longDescription = arguments?["longDescription"]?.stringValue
        let dryRun = arguments?["dryRun"]?.boolValue ?? false

        // Validate character limits for localization fields
        if let name = name {
            let (valid, error) = CharLimitValidator.validate(
                name, field: "Name", maxChars: 30)
            if !valid {
                return .init(content: [.text("Error: \(error!)")], isError: true)
            }
        }
        if let sd = shortDescription {
            let (valid, error) = CharLimitValidator.validate(
                sd, field: "Short description", maxChars: 50)
            if !valid {
                return .init(content: [.text("Error: \(error!)")], isError: true)
            }
        }
        if let ld = longDescription {
            let (valid, error) = CharLimitValidator.validate(
                ld, field: "Long description", maxChars: 120)
            if !valid {
                return .init(content: [.text("Error: \(error!)")], isError: true)
            }
        }

        // Validate locale if provided
        if let locale = locale {
            if !LocaleHelper.validate(locale) {
                return .init(
                    content: [
                        .text(
                            "Error: Invalid locale '\(locale)'. Use list_locales to see valid locales."
                        )
                    ],
                    isError: true)
            }
        }

        // Map badge
        var badge: AppEventCreateRequest.Data.Attributes.Badge? = nil
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
        }

        // Map priority
        var priority: AppEventCreateRequest.Data.Attributes.Priority? = nil
        if let priorityStr = priorityStr {
            switch priorityStr {
            case "HIGH": priority = .high
            case "NORMAL": priority = .normal
            default:
                return .init(
                    content: [.text("Error: Invalid priority '\(priorityStr)'")],
                    isError: true)
            }
        }

        // Map purpose
        var purpose: AppEventCreateRequest.Data.Attributes.Purpose? = nil
        if let purposeStr = purposeStr {
            switch purposeStr {
            case "APPROPRIATE_FOR_ALL_USERS": purpose = .appropriateForAllUsers
            case "ATTRACT_NEW_USERS": purpose = .attractNewUsers
            case "KEEP_ACTIVE_USERS_INFORMED": purpose = .keepActiveUsersInformed
            case "BRING_BACK_LAPSED_USERS": purpose = .bringBackLapsedUsers
            default:
                return .init(
                    content: [.text("Error: Invalid purpose '\(purposeStr)'")],
                    isError: true)
            }
        }

        // Parse deep link
        var deepLink: URL? = nil
        if let deepLinkStr = deepLinkStr {
            guard let url = URL(string: deepLinkStr) else {
                return .init(
                    content: [
                        .text("Error: Invalid deep link URL '\(deepLinkStr)'")
                    ],
                    isError: true)
            }
            deepLink = url
        }

        // Parse territory schedules
        var territorySchedules:
            [AppEventCreateRequest.Data.Attributes.TerritorySchedule]? = nil
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
        }

        // Build result preview
        var resultDict: [String: Any] = [
            "appId": appId,
            "referenceName": referenceName,
        ]
        if let b = badgeStr { resultDict["badge"] = b }
        if let dl = deepLinkStr { resultDict["deepLink"] = dl }
        if let pr = purchaseRequirement { resultDict["purchaseRequirement"] = pr }
        if let pl = primaryLocale { resultDict["primaryLocale"] = pl }
        if let p = priorityStr { resultDict["priority"] = p }
        if let pu = purposeStr { resultDict["purpose"] = pu }

        if let locale = locale {
            var locResult: [String: Any] = ["locale": locale]
            if let n = name { locResult["name"] = "\(n) (\(n.count)/30)" }
            if let sd = shortDescription {
                locResult["shortDescription"] = "\(sd) (\(sd.count)/50)"
            }
            if let ld = longDescription {
                locResult["longDescription"] = "\(ld) (\(ld.count)/120)"
            }
            resultDict["localization"] = locResult
        }

        if dryRun {
            resultDict["status"] = "dry_run"
            let json = try JSONSerialization.data(
                withJSONObject: resultDict,
                options: [.prettyPrinted, .sortedKeys])
            return .init(
                content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        // Create the event
        let request = AppEventCreateRequest(
            data: .init(
                attributes: .init(
                    referenceName: referenceName,
                    badge: badge,
                    deepLink: deepLink,
                    purchaseRequirement: purchaseRequirement,
                    primaryLocale: primaryLocale,
                    priority: priority,
                    purpose: purpose,
                    territorySchedules: territorySchedules
                ),
                relationships: .init(
                    app: .init(data: .init(id: appId))
                )
            )
        )

        let eventResponse = try await client.send(
            Resources.v1.appEvents.post(request)
        )
        let createdEvent = eventResponse.data
        resultDict["status"] = "created"
        resultDict["eventId"] = createdEvent.id

        // Create initial localization if locale provided
        if let locale = locale {
            let locRequest = AppEventLocalizationCreateRequest(
                data: .init(
                    attributes: .init(
                        locale: locale,
                        name: name,
                        shortDescription: shortDescription,
                        longDescription: longDescription
                    ),
                    relationships: .init(
                        appEvent: .init(data: .init(id: createdEvent.id))
                    )
                )
            )
            let locResponse = try await client.send(
                Resources.v1.appEventLocalizations.post(locRequest)
            )
            resultDict["localizationId"] = locResponse.data.id
        }

        let json = try JSONSerialization.data(
            withJSONObject: resultDict, options: [.prettyPrinted, .sortedKeys])
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
