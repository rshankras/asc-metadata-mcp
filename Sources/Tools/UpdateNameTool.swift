import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum UpdateNameTool {
    static let tool = Tool(
        name: "update_name",
        description: "Update app name and/or subtitle for a specific locale. Requires a version in 'Prepare for Submission' state.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "appId": .object(["type": "string", "description": "App Store app ID"]),
                "locale": .object([
                    "type": "string", "description": "Locale code (default: en-US)",
                    "default": "en-US",
                ]),
                "name": .object([
                    "type": "string", "description": "New app name (max 30 chars)",
                ]),
                "subtitle": .object([
                    "type": "string", "description": "New subtitle (max 30 chars)",
                ]),
                "dryRun": .object([
                    "type": "boolean", "description": "Preview changes without applying (default: false)",
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
        let locale = arguments?["locale"]?.stringValue ?? "en-US"
        let newName = arguments?["name"]?.stringValue
        let newSubtitle = arguments?["subtitle"]?.stringValue
        let dryRun = arguments?["dryRun"]?.boolValue ?? false

        guard newName != nil || newSubtitle != nil else {
            return .init(
                content: [.text("Error: At least one of 'name' or 'subtitle' must be provided")],
                isError: true)
        }

        // Validate character limits
        if let name = newName {
            let (valid, error) = CharLimitValidator.validate(name, field: "Name", maxChars: 30)
            if !valid { return .init(content: [.text("Error: \(error!)")], isError: true) }
        }
        if let subtitle = newSubtitle {
            let (valid, error) = CharLimitValidator.validate(subtitle, field: "Subtitle", maxChars: 30)
            if !valid { return .init(content: [.text("Error: \(error!)")], isError: true) }
        }

        // Find the app info localization
        let appInfosResponse = try await client.send(
            Resources.v1.apps.id(appId).appInfos.get()
        )
        guard let appInfo = appInfosResponse.data.first else {
            return .init(content: [.text("Error: No app info found for app \(appId)")], isError: true)
        }

        let infoLocsResponse = try await client.send(
            Resources.v1.appInfos.id(appInfo.id).appInfoLocalizations.get(
                filterLocale: [locale]
            )
        )
        guard let infoLoc = infoLocsResponse.data.first else {
            return .init(
                content: [.text("Error: No localization found for locale \(locale)")], isError: true)
        }

        let oldName = infoLoc.attributes?.name ?? ""
        let oldSubtitle = infoLoc.attributes?.subtitle ?? ""

        var changes: [String: Any] = [:]
        if let name = newName {
            changes["name"] = ["old": oldName, "new": name, "chars": "\(name.count)/30"]
        }
        if let subtitle = newSubtitle {
            changes["subtitle"] = [
                "old": oldSubtitle, "new": subtitle, "chars": "\(subtitle.count)/30",
            ]
        }

        if dryRun {
            let result: [String: Any] = ["status": "dry_run", "changes": changes]
            let json = try JSONSerialization.data(
                withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            return .init(content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        // Apply the update
        let updateRequest = AppInfoLocalizationUpdateRequest(
            data: .init(
                id: infoLoc.id,
                attributes: .init(
                    name: newName,
                    subtitle: newSubtitle
                )
            )
        )
        _ = try await client.send(
            Resources.v1.appInfoLocalizations.id(infoLoc.id).patch(updateRequest)
        )

        let result: [String: Any] = ["status": "updated", "changes": changes]
        let json = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return .init(content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
