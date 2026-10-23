import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum ListAppEventsTool {
    static let tool = Tool(
        name: "list_app_events",
        description:
            "List in-app events for an app with their localizations. Optionally filter by event state.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "appId": .object(["type": "string", "description": "App Store app ID"]),
                "eventState": .object([
                    "type": "string",
                    "description": "Filter by event state",
                    "enum": .array([
                        .string("DRAFT"), .string("READY_FOR_REVIEW"),
                        .string("WAITING_FOR_REVIEW"),
                        .string("IN_REVIEW"), .string("REJECTED"), .string("ACCEPTED"),
                        .string("APPROVED"), .string("PUBLISHED"), .string("PAST"),
                        .string("ARCHIVED"),
                    ]),
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
        let eventStateFilter = arguments?["eventState"]?.stringValue

        let response = try await client.send(
            Resources.v1.apps.id(appId).appEvents.get()
        )

        var filteredData = response.data
        if let stateStr = eventStateFilter {
            filteredData = filteredData.filter {
                $0.attributes?.eventState?.rawValue == stateStr
            }
        }

        let formatter = ISO8601DateFormatter()
        var events: [[String: Any]] = []

        for event in filteredData {
            let attrs = event.attributes
            var eventDict: [String: Any] = [
                "eventId": event.id,
                "referenceName": attrs?.referenceName ?? "",
                "eventState": attrs?.eventState?.rawValue ?? "",
            ]
            if let badge = attrs?.badge { eventDict["badge"] = badge.rawValue }
            if let priority = attrs?.priority { eventDict["priority"] = priority.rawValue }
            if let purpose = attrs?.purpose { eventDict["purpose"] = purpose.rawValue }
            if let deepLink = attrs?.deepLink {
                eventDict["deepLink"] = deepLink.absoluteString
            }
            if let pr = attrs?.purchaseRequirement {
                eventDict["purchaseRequirement"] = pr
            }
            if let pl = attrs?.primaryLocale { eventDict["primaryLocale"] = pl }

            if let schedules = attrs?.territorySchedules, !schedules.isEmpty {
                eventDict["territorySchedules"] = schedules.map {
                    sched -> [String: Any] in
                    var dict: [String: Any] = [:]
                    if let t = sched.territories { dict["territories"] = t }
                    if let d = sched.publishStart {
                        dict["publishStart"] = formatter.string(from: d)
                    }
                    if let d = sched.eventStart {
                        dict["eventStart"] = formatter.string(from: d)
                    }
                    if let d = sched.eventEnd {
                        dict["eventEnd"] = formatter.string(from: d)
                    }
                    return dict
                }
            }

            // Fetch localizations for this event
            let locsResponse = try await client.send(
                Resources.v1.appEvents.id(event.id).localizations.get()
            )
            if !locsResponse.data.isEmpty {
                eventDict["localizations"] = locsResponse.data.map {
                    loc -> [String: Any] in
                    var locDict: [String: Any] = [
                        "localizationId": loc.id,
                        "locale": loc.attributes?.locale ?? "",
                    ]
                    if let name = loc.attributes?.name { locDict["name"] = name }
                    if let sd = loc.attributes?.shortDescription {
                        locDict["shortDescription"] = sd
                    }
                    if let ld = loc.attributes?.longDescription {
                        locDict["longDescription"] = ld
                    }
                    return locDict
                }
            }

            events.append(eventDict)
        }

        let json = try JSONSerialization.data(
            withJSONObject: events, options: [.prettyPrinted, .sortedKeys])
        return .init(content: [.text(String(data: json, encoding: .utf8) ?? "[]")])
    }
}
