import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum UpdatePromoTextTool {
    static let tool = Tool(
        name: "update_promo_text",
        description: "Update promotional text for a specific locale. No app review needed — goes live immediately. Max 170 chars.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "appId": .object(["type": "string", "description": "App Store app ID"]),
                "locale": .object([
                    "type": "string", "description": "Locale code (default: en-US)",
                    "default": "en-US",
                ]),
                "promotionalText": .object([
                    "type": "string", "description": "Promotional text (max 170 chars)",
                ]),
                "dryRun": .object([
                    "type": "boolean", "description": "Preview changes without applying (default: false)",
                    "default": .bool(false),
                ]),
            ]),
            "required": .array([.string("appId"), .string("promotionalText")]),
        ])
    )

    static func handle(
        arguments: [String: Value]?,
        client: AppStoreConnectClient
    ) async throws -> CallTool.Result {
        guard let appId = arguments?["appId"]?.stringValue else {
            return .init(content: [.text("Error: appId is required")], isError: true)
        }
        guard let promoText = arguments?["promotionalText"]?.stringValue else {
            return .init(content: [.text("Error: promotionalText is required")], isError: true)
        }
        let locale = arguments?["locale"]?.stringValue ?? "en-US"
        let dryRun = arguments?["dryRun"]?.boolValue ?? false

        let (valid, error) = CharLimitValidator.validate(
            promoText, field: "Promotional text", maxChars: 170)
        if !valid { return .init(content: [.text("Error: \(error!)")], isError: true) }

        let versionLoc = try await findVersionLocalization(
            appId: appId, locale: locale, client: client)
        switch versionLoc {
        case .failure(let errorResult): return errorResult
        case .success(let loc):
            let oldPromo = loc.attributes?.promotionalText ?? ""

            if dryRun {
                let result: [String: Any] = [
                    "status": "dry_run",
                    "oldPromoText": oldPromo,
                    "oldCharCount": "\(oldPromo.count)/170",
                    "newPromoText": promoText,
                    "newCharCount": "\(promoText.count)/170",
                ]
                let json = try JSONSerialization.data(
                    withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
                return .init(content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
            }

            let updateRequest = AppStoreVersionLocalizationUpdateRequest(
                data: .init(id: loc.id, attributes: .init(promotionalText: promoText))
            )
            _ = try await client.send(
                Resources.v1.appStoreVersionLocalizations.id(loc.id).patch(updateRequest)
            )

            let result: [String: Any] = [
                "status": "updated",
                "charCount": "\(promoText.count)/170",
            ]
            let json = try JSONSerialization.data(
                withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            return .init(content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }
    }
}
