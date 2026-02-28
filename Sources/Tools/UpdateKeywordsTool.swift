import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum UpdateKeywordsTool {
    static let tool = Tool(
        name: "update_keywords",
        description: "Update the keywords field for a specific locale. Validates character count, warns about spaces, duplicates, and plural forms.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "appId": .object(["type": "string", "description": "App Store app ID"]),
                "locale": .object([
                    "type": "string", "description": "Locale code (default: en-US)",
                    "default": "en-US",
                ]),
                "keywords": .object([
                    "type": "string",
                    "description": "Comma-separated keywords, no spaces (max 100 chars)",
                ]),
                "dryRun": .object([
                    "type": "boolean", "description": "Preview changes without applying (default: false)",
                    "default": .bool(false),
                ]),
            ]),
            "required": .array([.string("appId"), .string("keywords")]),
        ])
    )

    static func handle(
        arguments: [String: Value]?,
        client: AppStoreConnectClient
    ) async throws -> CallTool.Result {
        guard let appId = arguments?["appId"]?.stringValue else {
            return .init(content: [.text("Error: appId is required")], isError: true)
        }
        guard let keywords = arguments?["keywords"]?.stringValue else {
            return .init(content: [.text("Error: keywords is required")], isError: true)
        }
        let locale = arguments?["locale"]?.stringValue ?? "en-US"
        let dryRun = arguments?["dryRun"]?.boolValue ?? false

        // Validate keywords
        let validation = KeywordValidator.validate(keywords)
        if !validation.isValid {
            return .init(content: [.text("Error: \(validation.error!)")], isError: true)
        }

        // Find the version localization
        let versionsResponse = try await client.send(
            Resources.v1.apps.id(appId).appStoreVersions.get()
        )
        guard let version = versionsResponse.data.first else {
            return .init(
                content: [.text("Error: No app store version found for app \(appId)")], isError: true
            )
        }

        let versionLocsResponse = try await client.send(
            Resources.v1.appStoreVersions.id(version.id).appStoreVersionLocalizations.get(
                filterLocale: [locale]
            )
        )
        guard let versionLoc = versionLocsResponse.data.first else {
            return .init(
                content: [.text("Error: No version localization found for locale \(locale)")],
                isError: true)
        }

        let oldKeywords = versionLoc.attributes?.keywords ?? ""

        if dryRun {
            let result: [String: Any] = [
                "status": "dry_run",
                "oldKeywords": oldKeywords,
                "oldCharCount": "\(oldKeywords.count)/100",
                "newKeywords": keywords,
                "newCharCount": "\(validation.charCount)/\(validation.maxChars)",
                "warnings": validation.warnings,
            ]
            let json = try JSONSerialization.data(
                withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            return .init(content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        // Apply the update
        let updateRequest = AppStoreVersionLocalizationUpdateRequest(
            data: .init(
                id: versionLoc.id,
                attributes: .init(keywords: keywords)
            )
        )
        _ = try await client.send(
            Resources.v1.appStoreVersionLocalizations.id(versionLoc.id).patch(updateRequest)
        )

        let result: [String: Any] = [
            "status": "updated",
            "keywords": keywords,
            "charCount": "\(validation.charCount)/\(validation.maxChars)",
            "warnings": validation.warnings,
        ]
        let json = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return .init(content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
