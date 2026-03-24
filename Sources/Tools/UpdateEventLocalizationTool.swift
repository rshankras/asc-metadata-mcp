import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum UpdateEventLocalizationTool {
    static let tool = Tool(
        name: "update_event_localization",
        description:
            "Create or update an in-app event localization. If the locale already exists for the event, updates it; otherwise creates a new localization.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "eventId": .object([
                    "type": "string", "description": "In-app event ID",
                ]),
                "locale": .object([
                    "type": "string",
                    "description": "Locale code (e.g. en-US, de-DE)",
                ]),
                "name": .object([
                    "type": "string",
                    "description": "Event name (max 30 chars)",
                ]),
                "shortDescription": .object([
                    "type": "string",
                    "description": "Short description (max 50 chars)",
                ]),
                "longDescription": .object([
                    "type": "string",
                    "description": "Long description (max 120 chars)",
                ]),
                "dryRun": .object([
                    "type": "boolean",
                    "description":
                        "Preview changes without applying (default: false)",
                    "default": .bool(false),
                ]),
            ]),
            "required": .array([.string("eventId"), .string("locale")]),
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
        guard let locale = arguments?["locale"]?.stringValue else {
            return .init(
                content: [.text("Error: locale is required")], isError: true)
        }
        let name = arguments?["name"]?.stringValue
        let shortDescription = arguments?["shortDescription"]?.stringValue
        let longDescription = arguments?["longDescription"]?.stringValue
        let dryRun = arguments?["dryRun"]?.boolValue ?? false

        // Validate locale
        if !LocaleHelper.validate(locale) {
            return .init(
                content: [
                    .text(
                        "Error: Invalid locale '\(locale)'. Use list_locales to see valid locales."
                    )
                ],
                isError: true)
        }

        // Validate at least one text field
        guard name != nil || shortDescription != nil || longDescription != nil
        else {
            return .init(
                content: [
                    .text(
                        "Error: At least one of name, shortDescription, or longDescription must be provided"
                    )
                ],
                isError: true)
        }

        // Validate character limits
        if let n = name {
            let (valid, error) = CharLimitValidator.validate(
                n, field: "Name", maxChars: 30)
            if !valid {
                return .init(
                    content: [.text("Error: \(error!)")], isError: true)
            }
        }
        if let sd = shortDescription {
            let (valid, error) = CharLimitValidator.validate(
                sd, field: "Short description", maxChars: 50)
            if !valid {
                return .init(
                    content: [.text("Error: \(error!)")], isError: true)
            }
        }
        if let ld = longDescription {
            let (valid, error) = CharLimitValidator.validate(
                ld, field: "Long description", maxChars: 120)
            if !valid {
                return .init(
                    content: [.text("Error: \(error!)")], isError: true)
            }
        }

        // Fetch existing localizations for this event
        let locsResponse = try await client.send(
            Resources.v1.appEvents.id(eventId).localizations.get()
        )
        let existingLoc = locsResponse.data.first {
            $0.attributes?.locale == locale
        }

        if let existing = existingLoc {
            // UPDATE existing localization
            let oldName = existing.attributes?.name ?? ""
            let oldShortDesc = existing.attributes?.shortDescription ?? ""
            let oldLongDesc = existing.attributes?.longDescription ?? ""

            var changes: [String: Any] = [:]
            if let n = name {
                changes["name"] = [
                    "old": oldName, "new": n, "chars": "\(n.count)/30",
                ]
            }
            if let sd = shortDescription {
                changes["shortDescription"] = [
                    "old": oldShortDesc, "new": sd,
                    "chars": "\(sd.count)/50",
                ]
            }
            if let ld = longDescription {
                changes["longDescription"] = [
                    "old": oldLongDesc, "new": ld,
                    "chars": "\(ld.count)/120",
                ]
            }

            if dryRun {
                let result: [String: Any] = [
                    "status": "dry_run",
                    "action": "update",
                    "localizationId": existing.id,
                    "locale": locale,
                    "changes": changes,
                ]
                let json = try JSONSerialization.data(
                    withJSONObject: result,
                    options: [.prettyPrinted, .sortedKeys])
                return .init(
                    content: [
                        .text(String(data: json, encoding: .utf8) ?? "{}")
                    ])
            }

            let updateRequest = AppEventLocalizationUpdateRequest(
                data: .init(
                    id: existing.id,
                    attributes: .init(
                        name: name,
                        shortDescription: shortDescription,
                        longDescription: longDescription
                    )
                )
            )
            _ = try await client.send(
                Resources.v1.appEventLocalizations.id(existing.id).patch(
                    updateRequest)
            )

            let result: [String: Any] = [
                "status": "updated",
                "localizationId": existing.id,
                "locale": locale,
                "changes": changes,
            ]
            let json = try JSONSerialization.data(
                withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            return .init(
                content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        } else {
            // CREATE new localization
            var preview: [String: Any] = ["locale": locale]
            if let n = name { preview["name"] = "\(n) (\(n.count)/30)" }
            if let sd = shortDescription {
                preview["shortDescription"] = "\(sd) (\(sd.count)/50)"
            }
            if let ld = longDescription {
                preview["longDescription"] = "\(ld) (\(ld.count)/120)"
            }

            if dryRun {
                let result: [String: Any] = [
                    "status": "dry_run",
                    "action": "create",
                    "localization": preview,
                ]
                let json = try JSONSerialization.data(
                    withJSONObject: result,
                    options: [.prettyPrinted, .sortedKeys])
                return .init(
                    content: [
                        .text(String(data: json, encoding: .utf8) ?? "{}")
                    ])
            }

            let createRequest = AppEventLocalizationCreateRequest(
                data: .init(
                    attributes: .init(
                        locale: locale,
                        name: name,
                        shortDescription: shortDescription,
                        longDescription: longDescription
                    ),
                    relationships: .init(
                        appEvent: .init(data: .init(id: eventId))
                    )
                )
            )
            let createResponse = try await client.send(
                Resources.v1.appEventLocalizations.post(createRequest)
            )

            let result: [String: Any] = [
                "status": "created",
                "localizationId": createResponse.data.id,
                "locale": locale,
                "localization": preview,
            ]
            let json = try JSONSerialization.data(
                withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            return .init(
                content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }
    }
}
