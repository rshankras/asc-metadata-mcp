import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum GetMetadataTool {
    static let tool = Tool(
        name: "get_metadata",
        description: "Read current metadata for an app in a specific locale. Returns name, subtitle, keywords, description, promotional text, what's new, and character counts.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "appId": .object(["type": "string", "description": "App Store app ID"]),
                "locale": .object([
                    "type": "string", "description": "Locale code (default: en-US)",
                    "default": "en-US",
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

        // Get app info localizations (name, subtitle).
        // Prefer the editable AppInfo (e.g. PREPARE_FOR_SUBMISSION) when one exists, so the
        // returned name/subtitle reflects the prepared version instead of the live one.
        // See AppInfoSelector for the why.
        let appInfosResponse = try await client.send(
            Resources.v1.apps.id(appId).appInfos.get()
        )
        guard let appInfo = AppInfoSelector.findPreferredOrFirst(in: appInfosResponse.data) else {
            return .init(content: [.text("Error: No app info found for app \(appId)")], isError: true)
        }

        let infoLocsResponse = try await client.send(
            Resources.v1.appInfos.id(appInfo.id).appInfoLocalizations.get(
                filterLocale: [locale]
            )
        )
        let infoLoc = infoLocsResponse.data.first

        // Get app store version localizations (description, keywords, promo text, whats new)
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
        let versionLoc = versionLocsResponse.data.first

        let name = infoLoc?.attributes?.name ?? ""
        let subtitle = infoLoc?.attributes?.subtitle ?? ""
        let keywords = versionLoc?.attributes?.keywords ?? ""
        let description = versionLoc?.attributes?.description ?? ""
        let promotionalText = versionLoc?.attributes?.promotionalText ?? ""
        let whatsNew = versionLoc?.attributes?.whatsNew ?? ""
        let versionString = version.attributes?.versionString ?? ""

        let result: [String: Any] = [
            "appId": appId,
            "locale": locale,
            "name": name,
            "nameCharCount": "\(name.count)/30",
            "subtitle": subtitle,
            "subtitleCharCount": "\(subtitle.count)/30",
            "keywords": keywords,
            "keywordsCharCount": "\(keywords.count)/100",
            "description": description,
            "descriptionCharCount": "\(description.count)/4000",
            "promotionalText": promotionalText,
            "promoTextCharCount": "\(promotionalText.count)/170",
            "whatsNew": whatsNew,
            "whatsNewCharCount": "\(whatsNew.count)/4000",
            "version": versionString,
        ]

        let json = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        let text = String(data: json, encoding: .utf8) ?? "{}"
        return .init(content: [.text(text)])
    }
}
