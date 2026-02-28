import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum UpdateWhatsNewTool {
    static let tool = Tool(
        name: "update_whats_new",
        description: "Update release notes / what's new text for a specific locale (max 4000 chars).",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "appId": .object(["type": "string", "description": "App Store app ID"]),
                "locale": .object([
                    "type": "string", "description": "Locale code (default: en-US)",
                    "default": "en-US",
                ]),
                "whatsNew": .object([
                    "type": "string", "description": "Release notes text (max 4000 chars)",
                ]),
                "dryRun": .object([
                    "type": "boolean", "description": "Preview changes without applying (default: false)",
                    "default": .bool(false),
                ]),
            ]),
            "required": .array([.string("appId"), .string("whatsNew")]),
        ])
    )

    static func handle(
        arguments: [String: Value]?,
        client: AppStoreConnectClient
    ) async throws -> CallTool.Result {
        guard let appId = arguments?["appId"]?.stringValue else {
            return .init(content: [.text("Error: appId is required")], isError: true)
        }
        guard let whatsNew = arguments?["whatsNew"]?.stringValue else {
            return .init(content: [.text("Error: whatsNew is required")], isError: true)
        }
        let locale = arguments?["locale"]?.stringValue ?? "en-US"
        let dryRun = arguments?["dryRun"]?.boolValue ?? false

        let (valid, error) = CharLimitValidator.validate(
            whatsNew, field: "What's New", maxChars: 4000)
        if !valid { return .init(content: [.text("Error: \(error!)")], isError: true) }

        let versionLoc = try await findVersionLocalization(
            appId: appId, locale: locale, client: client)
        switch versionLoc {
        case .failure(let errorResult): return errorResult
        case .success(let loc):
            let oldWhatsNew = loc.attributes?.whatsNew ?? ""

            if dryRun {
                let result: [String: Any] = [
                    "status": "dry_run",
                    "oldWhatsNew": oldWhatsNew,
                    "oldCharCount": "\(oldWhatsNew.count)/4000",
                    "newWhatsNew": whatsNew,
                    "newCharCount": "\(whatsNew.count)/4000",
                ]
                let json = try JSONSerialization.data(
                    withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
                return .init(content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
            }

            let updateRequest = AppStoreVersionLocalizationUpdateRequest(
                data: .init(id: loc.id, attributes: .init(whatsNew: whatsNew))
            )
            _ = try await client.send(
                Resources.v1.appStoreVersionLocalizations.id(loc.id).patch(updateRequest)
            )

            let result: [String: Any] = [
                "status": "updated",
                "charCount": "\(whatsNew.count)/4000",
            ]
            let json = try JSONSerialization.data(
                withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            return .init(content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }
    }
}
