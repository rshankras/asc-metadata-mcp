import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum BulkUpdateTool {
    static let tool = Tool(
        name: "bulk_update",
        description: "Update multiple metadata fields at once for a locale. The main tool for pushing ASO content. Supports keywords, description, promotional text, and what's new.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "appId": .object(["type": "string", "description": "App Store app ID"]),
                "locale": .object([
                    "type": "string", "description": "Locale code (default: en-US)",
                    "default": "en-US",
                ]),
                "keywords": .object([
                    "type": "string", "description": "Keywords (100 chars max)",
                ]),
                "description": .object([
                    "type": "string", "description": "Description (4000 chars max)",
                ]),
                "promotionalText": .object([
                    "type": "string", "description": "Promotional text (170 chars max)",
                ]),
                "whatsNew": .object([
                    "type": "string", "description": "Release notes (4000 chars max)",
                ]),
                "dryRun": .object([
                    "type": "boolean", "description": "Preview all changes without applying (default: false)",
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
        let dryRun = arguments?["dryRun"]?.boolValue ?? false

        let newKeywords = arguments?["keywords"]?.stringValue
        let newDescription = arguments?["description"]?.stringValue
        let newPromoText = arguments?["promotionalText"]?.stringValue
        let newWhatsNew = arguments?["whatsNew"]?.stringValue

        guard newKeywords != nil || newDescription != nil || newPromoText != nil || newWhatsNew != nil
        else {
            return .init(
                content: [
                    .text(
                        "Error: At least one field (keywords, description, promotionalText, whatsNew) must be provided"
                    )
                ], isError: true)
        }

        // Validate all fields before making any changes
        var validationErrors: [String] = []
        var warnings: [String] = []

        if let keywords = newKeywords {
            let validation = KeywordValidator.validate(keywords)
            if !validation.isValid {
                validationErrors.append(validation.error!)
            }
            warnings.append(contentsOf: validation.warnings)
        }
        if let desc = newDescription {
            let (valid, error) = CharLimitValidator.validate(desc, field: "Description", maxChars: 4000)
            if !valid { validationErrors.append(error!) }
        }
        if let promo = newPromoText {
            let (valid, error) = CharLimitValidator.validate(
                promo, field: "Promotional text", maxChars: 170)
            if !valid { validationErrors.append(error!) }
        }
        if let whatsNew = newWhatsNew {
            let (valid, error) = CharLimitValidator.validate(
                whatsNew, field: "What's New", maxChars: 4000)
            if !valid { validationErrors.append(error!) }
        }

        if !validationErrors.isEmpty {
            return .init(
                content: [.text("Validation errors:\n" + validationErrors.joined(separator: "\n"))],
                isError: true)
        }

        // Find version localization
        let versionLoc = try await findVersionLocalization(
            appId: appId, locale: locale, client: client)
        switch versionLoc {
        case .failure(let errorResult): return errorResult
        case .success(let loc):
            var changes: [String: Any] = [:]

            if let keywords = newKeywords {
                let old = loc.attributes?.keywords ?? ""
                changes["keywords"] = [
                    "old": old, "new": keywords,
                    "oldCharCount": "\(old.count)/100", "newCharCount": "\(keywords.count)/100",
                ]
            }
            if let desc = newDescription {
                let old = loc.attributes?.description ?? ""
                changes["description"] = [
                    "old": old, "new": desc,
                    "oldCharCount": "\(old.count)/4000", "newCharCount": "\(desc.count)/4000",
                ]
            }
            if let promo = newPromoText {
                let old = loc.attributes?.promotionalText ?? ""
                changes["promotionalText"] = [
                    "old": old, "new": promo,
                    "oldCharCount": "\(old.count)/170", "newCharCount": "\(promo.count)/170",
                ]
            }
            if let whatsNew = newWhatsNew {
                let old = loc.attributes?.whatsNew ?? ""
                changes["whatsNew"] = [
                    "old": old, "new": whatsNew,
                    "oldCharCount": "\(old.count)/4000", "newCharCount": "\(whatsNew.count)/4000",
                ]
            }

            if dryRun {
                var result: [String: Any] = ["status": "dry_run", "changes": changes]
                if !warnings.isEmpty { result["warnings"] = warnings }
                let json = try JSONSerialization.data(
                    withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
                return .init(content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
            }

            // Apply the update — single PATCH with all fields
            let updateRequest = AppStoreVersionLocalizationUpdateRequest(
                data: .init(
                    id: loc.id,
                    attributes: .init(
                        description: newDescription,
                        keywords: newKeywords,
                        promotionalText: newPromoText,
                        whatsNew: newWhatsNew
                    )
                )
            )
            _ = try await client.send(
                Resources.v1.appStoreVersionLocalizations.id(loc.id).patch(updateRequest)
            )

            var result: [String: Any] = [
                "status": "updated",
                "fieldsUpdated": changes.keys.sorted(),
            ]
            if !warnings.isEmpty { result["warnings"] = warnings }
            let json = try JSONSerialization.data(
                withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            return .init(content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }
    }
}
