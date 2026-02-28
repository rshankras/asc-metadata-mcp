import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum UpdateDescriptionTool {
    static let tool = Tool(
        name: "update_description",
        description: "Update the full app description for a specific locale (max 4000 chars).",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "appId": .object(["type": "string", "description": "App Store app ID"]),
                "locale": .object([
                    "type": "string", "description": "Locale code (default: en-US)",
                    "default": "en-US",
                ]),
                "description": .object([
                    "type": "string", "description": "Full description text (max 4000 chars)",
                ]),
                "dryRun": .object([
                    "type": "boolean", "description": "Preview changes without applying (default: false)",
                    "default": .bool(false),
                ]),
            ]),
            "required": .array([.string("appId"), .string("description")]),
        ])
    )

    static func handle(
        arguments: [String: Value]?,
        client: AppStoreConnectClient
    ) async throws -> CallTool.Result {
        guard let appId = arguments?["appId"]?.stringValue else {
            return .init(content: [.text("Error: appId is required")], isError: true)
        }
        guard let description = arguments?["description"]?.stringValue else {
            return .init(content: [.text("Error: description is required")], isError: true)
        }
        let locale = arguments?["locale"]?.stringValue ?? "en-US"
        let dryRun = arguments?["dryRun"]?.boolValue ?? false

        let (valid, error) = CharLimitValidator.validate(
            description, field: "Description", maxChars: 4000)
        if !valid { return .init(content: [.text("Error: \(error!)")], isError: true) }

        let versionLoc = try await findVersionLocalization(
            appId: appId, locale: locale, client: client)
        switch versionLoc {
        case .failure(let errorResult): return errorResult
        case .success(let loc):
            let oldDescription = loc.attributes?.description ?? ""

            if dryRun {
                let result: [String: Any] = [
                    "status": "dry_run",
                    "oldCharCount": "\(oldDescription.count)/4000",
                    "newCharCount": "\(description.count)/4000",
                    "oldDescription": oldDescription,
                    "newDescription": description,
                ]
                let json = try JSONSerialization.data(
                    withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
                return .init(content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
            }

            let updateRequest = AppStoreVersionLocalizationUpdateRequest(
                data: .init(id: loc.id, attributes: .init(description: description))
            )
            _ = try await client.send(
                Resources.v1.appStoreVersionLocalizations.id(loc.id).patch(updateRequest)
            )

            let result: [String: Any] = [
                "status": "updated",
                "charCount": "\(description.count)/4000",
            ]
            let json = try JSONSerialization.data(
                withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            return .init(content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }
    }
}
