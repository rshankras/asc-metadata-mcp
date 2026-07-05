import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum GetAgeRatingTool {
    static let tool = Tool(
        name: "get_age_rating",
        description:
            "Get age rating declaration for an app. Returns all content descriptors and age rating overrides.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "appId": .object([
                    "type": "string",
                    "description": "App Store app ID",
                ])
            ]),
            "required": .array([.string("appId")]),
        ])
    )

    static func handle(
        arguments: [String: Value]?,
        client: AppStoreConnectClient
    ) async throws -> CallTool.Result {
        guard let appId = arguments?["appId"]?.stringValue else {
            return .init(
                content: [.text("Error: appId is required")], isError: true)
        }

        // Get app infos with age rating declaration included
        let appInfosResponse = try await client.send(
            Resources.v1.apps.id(appId).appInfos.get(
                fieldsAgeRatingDeclarations: [
                    .advertising, .alcoholTobaccoOrDrugUseOrReferences, .contests,
                    .gambling, .gamblingSimulated, .gunsOrOtherWeapons,
                    .healthOrWellnessTopics, .kidsAgeBand, .lootBox,
                    .medicalOrTreatmentInformation, .messagingAndChat,
                    .parentalControls, .profanityOrCrudeHumor, .ageAssurance,
                    .sexualContentGraphicAndNudity, .sexualContentOrNudity,
                    .horrorOrFearThemes, .matureOrSuggestiveThemes,
                    .unrestrictedWebAccess, .userGeneratedContent,
                    .violenceCartoonOrFantasy,
                    .violenceRealisticProlongedGraphicOrSadistic,
                    .violenceRealistic, .ageRatingOverride, .ageRatingOverrideV2,
                    .koreaAgeRatingOverride, .developerAgeRatingInfoURL,
                ],
                include: [.ageRatingDeclaration]
            )
        )

        guard let appInfo = appInfosResponse.data.first else {
            return .init(
                content: [.text("Error: No app info found for app \(appId)")],
                isError: true)
        }

        // Find the age rating declaration from included resources
        var declaration: AgeRatingDeclaration? = nil
        if let included = appInfosResponse.included {
            for item in included {
                if case .ageRatingDeclaration(let ard) = item {
                    declaration = ard
                    break
                }
            }
        }

        guard let decl = declaration else {
            return .init(
                content: [
                    .text(
                        "Error: No age rating declaration found for app \(appId)"
                    )
                ],
                isError: true)
        }

        let attrs = decl.attributes

        var result: [String: Any] = [
            "declarationId": decl.id,
            "appId": appId,
        ]

        // App-level age ratings from appInfo
        let appAttrs = appInfo.attributes
        if let ageRating = appAttrs?.appStoreAgeRating {
            result["appStoreAgeRating"] = ageRating.rawValue
        }
        if let koreaRating = appAttrs?.koreaAgeRating {
            result["koreaAgeRating"] = koreaRating.rawValue
        }
        if let brazilRating = appAttrs?.brazilAgeRatingV2 {
            result["brazilAgeRatingV2"] = brazilRating.rawValue
        }
        if let kidsAgeBand = appAttrs?.kidsAgeBand {
            result["kidsAgeBand"] = kidsAgeBand.rawValue
        }

        // Boolean content descriptors
        var booleanDescriptors: [String: Any] = [:]
        if let v = attrs?.isAdvertising { booleanDescriptors["advertising"] = v }
        if let v = attrs?.isGambling { booleanDescriptors["gambling"] = v }
        if let v = attrs?.isHealthOrWellnessTopics {
            booleanDescriptors["healthOrWellnessTopics"] = v
        }
        if let v = attrs?.isLootBox { booleanDescriptors["lootBox"] = v }
        if let v = attrs?.isMessagingAndChat {
            booleanDescriptors["messagingAndChat"] = v
        }
        if let v = attrs?.isParentalControls {
            booleanDescriptors["parentalControls"] = v
        }
        if let v = attrs?.isAgeAssurance {
            booleanDescriptors["ageAssurance"] = v
        }
        if let v = attrs?.isUnrestrictedWebAccess {
            booleanDescriptors["unrestrictedWebAccess"] = v
        }
        if let v = attrs?.isUserGeneratedContent {
            booleanDescriptors["userGeneratedContent"] = v
        }
        result["booleanDescriptors"] = booleanDescriptors

        // Frequency-based content descriptors
        var frequencyDescriptors: [String: Any] = [:]
        if let v = attrs?.alcoholTobaccoOrDrugUseOrReferences {
            frequencyDescriptors["alcoholTobaccoOrDrugUseOrReferences"] =
                v.rawValue
        }
        if let v = attrs?.contests {
            frequencyDescriptors["contests"] = v.rawValue
        }
        if let v = attrs?.gamblingSimulated {
            frequencyDescriptors["gamblingSimulated"] = v.rawValue
        }
        if let v = attrs?.gunsOrOtherWeapons {
            frequencyDescriptors["gunsOrOtherWeapons"] = v.rawValue
        }
        if let v = attrs?.medicalOrTreatmentInformation {
            frequencyDescriptors["medicalOrTreatmentInformation"] = v.rawValue
        }
        if let v = attrs?.profanityOrCrudeHumor {
            frequencyDescriptors["profanityOrCrudeHumor"] = v.rawValue
        }
        if let v = attrs?.sexualContentGraphicAndNudity {
            frequencyDescriptors["sexualContentGraphicAndNudity"] = v.rawValue
        }
        if let v = attrs?.sexualContentOrNudity {
            frequencyDescriptors["sexualContentOrNudity"] = v.rawValue
        }
        if let v = attrs?.horrorOrFearThemes {
            frequencyDescriptors["horrorOrFearThemes"] = v.rawValue
        }
        if let v = attrs?.matureOrSuggestiveThemes {
            frequencyDescriptors["matureOrSuggestiveThemes"] = v.rawValue
        }
        if let v = attrs?.violenceCartoonOrFantasy {
            frequencyDescriptors["violenceCartoonOrFantasy"] = v.rawValue
        }
        if let v = attrs?.violenceRealisticProlongedGraphicOrSadistic {
            frequencyDescriptors[
                "violenceRealisticProlongedGraphicOrSadistic"] = v.rawValue
        }
        if let v = attrs?.violenceRealistic {
            frequencyDescriptors["violenceRealistic"] = v.rawValue
        }
        result["frequencyDescriptors"] = frequencyDescriptors

        // Age rating overrides
        var overrides: [String: Any] = [:]
        if let v = attrs?.ageRatingOverride {
            overrides["ageRatingOverride"] = v.rawValue
        }
        if let v = attrs?.ageRatingOverrideV2 {
            overrides["ageRatingOverrideV2"] = v.rawValue
        }
        if let v = attrs?.koreaAgeRatingOverride {
            overrides["koreaAgeRatingOverride"] = v.rawValue
        }
        result["overrides"] = overrides

        if let v = attrs?.kidsAgeBand {
            result["kidsAgeBand_declaration"] = v.rawValue
        }
        if let url = attrs?.developerAgeRatingInfoURL {
            result["developerAgeRatingInfoUrl"] = url.absoluteString
        }

        let json = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return .init(
            content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
