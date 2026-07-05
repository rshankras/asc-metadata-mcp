import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum DeleteAppEventTool {
    static let tool = Tool(
        name: "delete_app_event",
        description: "Delete an in-app event. Fetches event details before deleting for confirmation.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "eventId": .object([
                    "type": "string",
                    "description": "In-app event ID to delete",
                ]),
                "dryRun": .object([
                    "type": "boolean",
                    "description":
                        "Preview what will be deleted without deleting (default: false)",
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
        let dryRun = arguments?["dryRun"]?.boolValue ?? false

        // Fetch the event to show what's being deleted
        let currentResponse = try await client.send(
            Resources.v1.appEvents.id(eventId).get()
        )
        let event = currentResponse.data
        let attrs = event.attributes

        var eventInfo: [String: Any] = [
            "eventId": event.id,
            "referenceName": attrs?.referenceName ?? "",
            "eventState": attrs?.eventState?.rawValue ?? "",
        ]
        if let badge = attrs?.badge { eventInfo["badge"] = badge.rawValue }
        if let priority = attrs?.priority {
            eventInfo["priority"] = priority.rawValue
        }
        if let purpose = attrs?.purpose {
            eventInfo["purpose"] = purpose.rawValue
        }
        if let deepLink = attrs?.deepLink {
            eventInfo["deepLink"] = deepLink.absoluteString
        }
        if let pl = attrs?.primaryLocale { eventInfo["primaryLocale"] = pl }

        if dryRun {
            let result: [String: Any] = [
                "status": "dry_run",
                "action": "delete",
                "event": eventInfo,
            ]
            let json = try JSONSerialization.data(
                withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            return .init(
                content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        // Delete the event
        _ = try await client.send(Resources.v1.appEvents.id(eventId).delete)

        let result: [String: Any] = [
            "status": "deleted",
            "event": eventInfo,
        ]
        let json = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return .init(
            content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
