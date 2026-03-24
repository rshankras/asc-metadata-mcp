import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum UpdateAgeRatingTool {
    static let tool = Tool(
        name: "update_age_rating",
        description:
            "Update age rating declaration content descriptors. Use get_age_rating first to get the declarationId and current values.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "declarationId": .object([
                    "type": "string",
                    "description":
                        "Age rating declaration ID (from get_age_rating)",
                ]),
                // Boolean descriptors
                "advertising": .object([
                    "type": "boolean",
                    "description": "App contains advertising",
                ]),
                "gambling": .object([
                    "type": "boolean",
                    "description": "App contains real gambling",
                ]),
                "healthOrWellnessTopics": .object([
                    "type": "boolean",
                    "description":
                        "App contains health or wellness topics",
                ]),
                "lootBox": .object([
                    "type": "boolean",
                    "description": "App contains loot boxes",
                ]),
                "messagingAndChat": .object([
                    "type": "boolean",
                    "description": "App contains messaging and chat",
                ]),
                "parentalControls": .object([
                    "type": "boolean",
                    "description": "App has parental controls",
                ]),
                "ageAssurance": .object([
                    "type": "boolean",
                    "description": "App uses age assurance",
                ]),
                "unrestrictedWebAccess": .object([
                    "type": "boolean",
                    "description": "App provides unrestricted web access",
                ]),
                "userGeneratedContent": .object([
                    "type": "boolean",
                    "description": "App has user-generated content",
                ]),
                // Frequency-based descriptors (NONE, INFREQUENT_OR_MILD, FREQUENT_OR_INTENSE)
                "alcoholTobaccoOrDrugUseOrReferences": .object([
                    "type": "string",
                    "description": "Alcohol, tobacco, or drug use or references",
                    "enum": .array([
                        .string("NONE"), .string("INFREQUENT_OR_MILD"),
                        .string("FREQUENT_OR_INTENSE"),
                    ]),
                ]),
                "contests": .object([
                    "type": "string",
                    "description": "Contests content level",
                    "enum": .array([
                        .string("NONE"), .string("INFREQUENT_OR_MILD"),
                        .string("FREQUENT_OR_INTENSE"),
                    ]),
                ]),
                "gamblingSimulated": .object([
                    "type": "string",
                    "description": "Simulated gambling content level",
                    "enum": .array([
                        .string("NONE"), .string("INFREQUENT_OR_MILD"),
                        .string("FREQUENT_OR_INTENSE"),
                    ]),
                ]),
                "gunsOrOtherWeapons": .object([
                    "type": "string",
                    "description": "Guns or other weapons content level",
                    "enum": .array([
                        .string("NONE"), .string("INFREQUENT_OR_MILD"),
                        .string("FREQUENT_OR_INTENSE"),
                    ]),
                ]),
                "medicalOrTreatmentInformation": .object([
                    "type": "string",
                    "description":
                        "Medical or treatment information content level",
                    "enum": .array([
                        .string("NONE"), .string("INFREQUENT_OR_MILD"),
                        .string("FREQUENT_OR_INTENSE"),
                    ]),
                ]),
                "profanityOrCrudeHumor": .object([
                    "type": "string",
                    "description": "Profanity or crude humor content level",
                    "enum": .array([
                        .string("NONE"), .string("INFREQUENT_OR_MILD"),
                        .string("FREQUENT_OR_INTENSE"),
                    ]),
                ]),
                "sexualContentGraphicAndNudity": .object([
                    "type": "string",
                    "description":
                        "Sexual content graphic and nudity content level",
                    "enum": .array([
                        .string("NONE"), .string("INFREQUENT_OR_MILD"),
                        .string("FREQUENT_OR_INTENSE"),
                    ]),
                ]),
                "sexualContentOrNudity": .object([
                    "type": "string",
                    "description": "Sexual content or nudity content level",
                    "enum": .array([
                        .string("NONE"), .string("INFREQUENT_OR_MILD"),
                        .string("FREQUENT_OR_INTENSE"),
                    ]),
                ]),
                "horrorOrFearThemes": .object([
                    "type": "string",
                    "description": "Horror or fear themes content level",
                    "enum": .array([
                        .string("NONE"), .string("INFREQUENT_OR_MILD"),
                        .string("FREQUENT_OR_INTENSE"),
                    ]),
                ]),
                "matureOrSuggestiveThemes": .object([
                    "type": "string",
                    "description":
                        "Mature or suggestive themes content level",
                    "enum": .array([
                        .string("NONE"), .string("INFREQUENT_OR_MILD"),
                        .string("FREQUENT_OR_INTENSE"),
                    ]),
                ]),
                "violenceCartoonOrFantasy": .object([
                    "type": "string",
                    "description":
                        "Violence cartoon or fantasy content level",
                    "enum": .array([
                        .string("NONE"), .string("INFREQUENT_OR_MILD"),
                        .string("FREQUENT_OR_INTENSE"),
                    ]),
                ]),
                "violenceRealisticProlongedGraphicOrSadistic": .object([
                    "type": "string",
                    "description":
                        "Violence realistic prolonged graphic or sadistic content level",
                    "enum": .array([
                        .string("NONE"), .string("INFREQUENT_OR_MILD"),
                        .string("FREQUENT_OR_INTENSE"),
                    ]),
                ]),
                "violenceRealistic": .object([
                    "type": "string",
                    "description": "Violence realistic content level",
                    "enum": .array([
                        .string("NONE"), .string("INFREQUENT_OR_MILD"),
                        .string("FREQUENT_OR_INTENSE"),
                    ]),
                ]),
                // Age rating overrides
                "ageRatingOverride": .object([
                    "type": "string",
                    "description": "Age rating override",
                    "enum": .array([
                        .string("NONE"), .string("SEVENTEEN_PLUS"),
                        .string("UNRATED"),
                    ]),
                ]),
                "koreaAgeRatingOverride": .object([
                    "type": "string",
                    "description": "Korea age rating override",
                    "enum": .array([
                        .string("NONE"), .string("FIFTEEN_PLUS"),
                        .string("NINETEEN_PLUS"),
                    ]),
                ]),
                "dryRun": .object([
                    "type": "boolean",
                    "description":
                        "Preview changes without applying (default: false)",
                    "default": .bool(false),
                ]),
            ]),
            "required": .array([.string("declarationId")]),
        ])
    )

    static func handle(
        arguments: [String: Value]?,
        client: AppStoreConnectClient
    ) async throws -> CallTool.Result {
        guard let declarationId = arguments?["declarationId"]?.stringValue
        else {
            return .init(
                content: [.text("Error: declarationId is required")],
                isError: true)
        }
        let dryRun = arguments?["dryRun"]?.boolValue ?? false

        // Build attributes from provided arguments
        var updateAttrs =
            AgeRatingDeclarationUpdateRequest.Data.Attributes()
        var changes: [String: Any] = [:]

        // Boolean descriptors
        if let v = arguments?["advertising"]?.boolValue {
            updateAttrs.isAdvertising = v
            changes["advertising"] = v
        }
        if let v = arguments?["gambling"]?.boolValue {
            updateAttrs.isGambling = v
            changes["gambling"] = v
        }
        if let v = arguments?["healthOrWellnessTopics"]?.boolValue {
            updateAttrs.isHealthOrWellnessTopics = v
            changes["healthOrWellnessTopics"] = v
        }
        if let v = arguments?["lootBox"]?.boolValue {
            updateAttrs.isLootBox = v
            changes["lootBox"] = v
        }
        if let v = arguments?["messagingAndChat"]?.boolValue {
            updateAttrs.isMessagingAndChat = v
            changes["messagingAndChat"] = v
        }
        if let v = arguments?["parentalControls"]?.boolValue {
            updateAttrs.isParentalControls = v
            changes["parentalControls"] = v
        }
        if let v = arguments?["ageAssurance"]?.boolValue {
            updateAttrs.isAgeAssurance = v
            changes["ageAssurance"] = v
        }
        if let v = arguments?["unrestrictedWebAccess"]?.boolValue {
            updateAttrs.isUnrestrictedWebAccess = v
            changes["unrestrictedWebAccess"] = v
        }
        if let v = arguments?["userGeneratedContent"]?.boolValue {
            updateAttrs.isUserGeneratedContent = v
            changes["userGeneratedContent"] = v
        }

        // Frequency-based descriptors
        if let v = arguments?["alcoholTobaccoOrDrugUseOrReferences"]?
            .stringValue
        {
            guard
                let mapped = mapFrequency(
                    v,
                    as: AgeRatingDeclarationUpdateRequest.Data.Attributes
                        .AlcoholTobaccoOrDrugUseOrReferences.self)
            else {
                return .init(
                    content: [
                        .text(
                            "Error: Invalid alcoholTobaccoOrDrugUseOrReferences value '\(v)'"
                        )
                    ],
                    isError: true)
            }
            updateAttrs.alcoholTobaccoOrDrugUseOrReferences = mapped
            changes["alcoholTobaccoOrDrugUseOrReferences"] = v
        }

        if let v = arguments?["contests"]?.stringValue {
            guard
                let mapped = mapFrequency(
                    v,
                    as: AgeRatingDeclarationUpdateRequest.Data.Attributes
                        .Contests.self)
            else {
                return .init(
                    content: [
                        .text("Error: Invalid contests value '\(v)'")
                    ],
                    isError: true)
            }
            updateAttrs.contests = mapped
            changes["contests"] = v
        }

        if let v = arguments?["gamblingSimulated"]?.stringValue {
            guard
                let mapped = mapFrequency(
                    v,
                    as: AgeRatingDeclarationUpdateRequest.Data.Attributes
                        .GamblingSimulated.self)
            else {
                return .init(
                    content: [
                        .text(
                            "Error: Invalid gamblingSimulated value '\(v)'"
                        )
                    ],
                    isError: true)
            }
            updateAttrs.gamblingSimulated = mapped
            changes["gamblingSimulated"] = v
        }

        if let v = arguments?["gunsOrOtherWeapons"]?.stringValue {
            guard
                let mapped = mapFrequency(
                    v,
                    as: AgeRatingDeclarationUpdateRequest.Data.Attributes
                        .GunsOrOtherWeapons.self)
            else {
                return .init(
                    content: [
                        .text(
                            "Error: Invalid gunsOrOtherWeapons value '\(v)'"
                        )
                    ],
                    isError: true)
            }
            updateAttrs.gunsOrOtherWeapons = mapped
            changes["gunsOrOtherWeapons"] = v
        }

        if let v = arguments?["medicalOrTreatmentInformation"]?.stringValue {
            guard
                let mapped = mapFrequency(
                    v,
                    as: AgeRatingDeclarationUpdateRequest.Data.Attributes
                        .MedicalOrTreatmentInformation.self)
            else {
                return .init(
                    content: [
                        .text(
                            "Error: Invalid medicalOrTreatmentInformation value '\(v)'"
                        )
                    ],
                    isError: true)
            }
            updateAttrs.medicalOrTreatmentInformation = mapped
            changes["medicalOrTreatmentInformation"] = v
        }

        if let v = arguments?["profanityOrCrudeHumor"]?.stringValue {
            guard
                let mapped = mapFrequency(
                    v,
                    as: AgeRatingDeclarationUpdateRequest.Data.Attributes
                        .ProfanityOrCrudeHumor.self)
            else {
                return .init(
                    content: [
                        .text(
                            "Error: Invalid profanityOrCrudeHumor value '\(v)'"
                        )
                    ],
                    isError: true)
            }
            updateAttrs.profanityOrCrudeHumor = mapped
            changes["profanityOrCrudeHumor"] = v
        }

        if let v = arguments?["sexualContentGraphicAndNudity"]?.stringValue {
            guard
                let mapped = mapFrequency(
                    v,
                    as: AgeRatingDeclarationUpdateRequest.Data.Attributes
                        .SexualContentGraphicAndNudity.self)
            else {
                return .init(
                    content: [
                        .text(
                            "Error: Invalid sexualContentGraphicAndNudity value '\(v)'"
                        )
                    ],
                    isError: true)
            }
            updateAttrs.sexualContentGraphicAndNudity = mapped
            changes["sexualContentGraphicAndNudity"] = v
        }

        if let v = arguments?["sexualContentOrNudity"]?.stringValue {
            guard
                let mapped = mapFrequency(
                    v,
                    as: AgeRatingDeclarationUpdateRequest.Data.Attributes
                        .SexualContentOrNudity.self)
            else {
                return .init(
                    content: [
                        .text(
                            "Error: Invalid sexualContentOrNudity value '\(v)'"
                        )
                    ],
                    isError: true)
            }
            updateAttrs.sexualContentOrNudity = mapped
            changes["sexualContentOrNudity"] = v
        }

        if let v = arguments?["horrorOrFearThemes"]?.stringValue {
            guard
                let mapped = mapFrequency(
                    v,
                    as: AgeRatingDeclarationUpdateRequest.Data.Attributes
                        .HorrorOrFearThemes.self)
            else {
                return .init(
                    content: [
                        .text(
                            "Error: Invalid horrorOrFearThemes value '\(v)'"
                        )
                    ],
                    isError: true)
            }
            updateAttrs.horrorOrFearThemes = mapped
            changes["horrorOrFearThemes"] = v
        }

        if let v = arguments?["matureOrSuggestiveThemes"]?.stringValue {
            guard
                let mapped = mapFrequency(
                    v,
                    as: AgeRatingDeclarationUpdateRequest.Data.Attributes
                        .MatureOrSuggestiveThemes.self)
            else {
                return .init(
                    content: [
                        .text(
                            "Error: Invalid matureOrSuggestiveThemes value '\(v)'"
                        )
                    ],
                    isError: true)
            }
            updateAttrs.matureOrSuggestiveThemes = mapped
            changes["matureOrSuggestiveThemes"] = v
        }

        if let v = arguments?["violenceCartoonOrFantasy"]?.stringValue {
            guard
                let mapped = mapFrequency(
                    v,
                    as: AgeRatingDeclarationUpdateRequest.Data.Attributes
                        .ViolenceCartoonOrFantasy.self)
            else {
                return .init(
                    content: [
                        .text(
                            "Error: Invalid violenceCartoonOrFantasy value '\(v)'"
                        )
                    ],
                    isError: true)
            }
            updateAttrs.violenceCartoonOrFantasy = mapped
            changes["violenceCartoonOrFantasy"] = v
        }

        if let v = arguments?[
            "violenceRealisticProlongedGraphicOrSadistic"]?.stringValue
        {
            guard
                let mapped = mapFrequency(
                    v,
                    as: AgeRatingDeclarationUpdateRequest.Data.Attributes
                        .ViolenceRealisticProlongedGraphicOrSadistic.self)
            else {
                return .init(
                    content: [
                        .text(
                            "Error: Invalid violenceRealisticProlongedGraphicOrSadistic value '\(v)'"
                        )
                    ],
                    isError: true)
            }
            updateAttrs.violenceRealisticProlongedGraphicOrSadistic = mapped
            changes["violenceRealisticProlongedGraphicOrSadistic"] = v
        }

        if let v = arguments?["violenceRealistic"]?.stringValue {
            guard
                let mapped = mapFrequency(
                    v,
                    as: AgeRatingDeclarationUpdateRequest.Data.Attributes
                        .ViolenceRealistic.self)
            else {
                return .init(
                    content: [
                        .text(
                            "Error: Invalid violenceRealistic value '\(v)'"
                        )
                    ],
                    isError: true)
            }
            updateAttrs.violenceRealistic = mapped
            changes["violenceRealistic"] = v
        }

        // Age rating overrides
        if let v = arguments?["ageRatingOverride"]?.stringValue {
            switch v {
            case "NONE": updateAttrs.ageRatingOverride = AgeRatingDeclarationUpdateRequest.Data.Attributes.AgeRatingOverride.none
            case "SEVENTEEN_PLUS": updateAttrs.ageRatingOverride = .seventeenPlus
            case "UNRATED": updateAttrs.ageRatingOverride = .unrated
            default:
                return .init(
                    content: [
                        .text(
                            "Error: Invalid ageRatingOverride value '\(v)'"
                        )
                    ],
                    isError: true)
            }
            changes["ageRatingOverride"] = v
        }

        if let v = arguments?["koreaAgeRatingOverride"]?.stringValue {
            switch v {
            case "NONE": updateAttrs.koreaAgeRatingOverride = AgeRatingDeclarationUpdateRequest.Data.Attributes.KoreaAgeRatingOverride.none
            case "FIFTEEN_PLUS":
                updateAttrs.koreaAgeRatingOverride = .fifteenPlus
            case "NINETEEN_PLUS":
                updateAttrs.koreaAgeRatingOverride = .nineteenPlus
            default:
                return .init(
                    content: [
                        .text(
                            "Error: Invalid koreaAgeRatingOverride value '\(v)'"
                        )
                    ],
                    isError: true)
            }
            changes["koreaAgeRatingOverride"] = v
        }

        guard !changes.isEmpty else {
            return .init(
                content: [
                    .text(
                        "Error: At least one content descriptor must be provided"
                    )
                ],
                isError: true)
        }

        if dryRun {
            let result: [String: Any] = [
                "status": "dry_run",
                "declarationId": declarationId,
                "changes": changes,
            ]
            let json = try JSONSerialization.data(
                withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            return .init(
                content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        // Apply update
        let request = AgeRatingDeclarationUpdateRequest(
            data: .init(
                id: declarationId,
                attributes: updateAttrs
            )
        )

        let response = try await client.send(
            Resources.v1.ageRatingDeclarations.id(declarationId).patch(request)
        )

        let updatedAttrs = response.data.attributes
        var resultDict: [String: Any] = [
            "status": "updated",
            "declarationId": declarationId,
            "changes": changes,
        ]

        // Include computed age ratings from response if available
        if let v = updatedAttrs?.ageRatingOverride {
            resultDict["ageRatingOverride"] = v.rawValue
        }

        let json = try JSONSerialization.data(
            withJSONObject: resultDict, options: [.prettyPrinted, .sortedKeys])
        return .init(
            content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }

    // Helper to map frequency string to any of the frequency enum types
    // All frequency enums share the same raw values
    private static func mapFrequency<T: RawRepresentable>(
        _ value: String, as type: T.Type
    ) -> T? where T.RawValue == String {
        return T(rawValue: value)
    }
}
