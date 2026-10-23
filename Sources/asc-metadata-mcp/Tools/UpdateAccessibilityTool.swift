import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum UpdateAccessibilityTool {
    static let tool = Tool(
        name: "update_accessibility",
        description:
            "Create or update accessibility declarations for an app. Lists existing declarations, creates new ones by device family, or updates existing ones.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "appId": .object([
                    "type": "string",
                    "description": "App Store app ID",
                ]),
                "declarationId": .object([
                    "type": "string",
                    "description":
                        "Accessibility declaration ID to update. If omitted and deviceFamily is provided, creates a new declaration.",
                ]),
                "deviceFamily": .object([
                    "type": "string",
                    "description":
                        "Device family for creating a new declaration (required for create)",
                    "enum": .array([
                        .string("IPHONE"), .string("IPAD"),
                        .string("APPLE_TV"), .string("APPLE_WATCH"),
                        .string("MAC"), .string("VISION"),
                    ]),
                ]),
                "supportsVoiceover": .object([
                    "type": "boolean",
                    "description": "App supports VoiceOver",
                ]),
                "supportsVoiceControl": .object([
                    "type": "boolean",
                    "description": "App supports Voice Control",
                ]),
                "supportsCaptions": .object([
                    "type": "boolean",
                    "description": "App supports captions/subtitles",
                ]),
                "supportsAudioDescriptions": .object([
                    "type": "boolean",
                    "description": "App supports audio descriptions",
                ]),
                "supportsDarkInterface": .object([
                    "type": "boolean",
                    "description": "App supports dark interface",
                ]),
                "supportsDifferentiateWithoutColorAlone": .object([
                    "type": "boolean",
                    "description":
                        "App supports differentiate without color alone",
                ]),
                "supportsLargerText": .object([
                    "type": "boolean",
                    "description": "App supports larger text/Dynamic Type",
                ]),
                "supportsReducedMotion": .object([
                    "type": "boolean",
                    "description": "App supports reduced motion",
                ]),
                "supportsSufficientContrast": .object([
                    "type": "boolean",
                    "description": "App supports sufficient contrast",
                ]),
                "publish": .object([
                    "type": "boolean",
                    "description":
                        "Publish the declaration (only for update, not create)",
                ]),
                "listOnly": .object([
                    "type": "boolean",
                    "description":
                        "Only list existing accessibility declarations without making changes (default: false)",
                    "default": .bool(false),
                ]),
                "dryRun": .object([
                    "type": "boolean",
                    "description":
                        "Preview changes without applying (default: false)",
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
            return .init(
                content: [.text("Error: appId is required")], isError: true)
        }
        let declarationId = arguments?["declarationId"]?.stringValue
        let deviceFamilyStr = arguments?["deviceFamily"]?.stringValue
        let listOnly = arguments?["listOnly"]?.boolValue ?? false
        let dryRun = arguments?["dryRun"]?.boolValue ?? false

        // List existing declarations
        if listOnly {
            let response = try await client.send(
                Resources.v1.apps.id(appId).accessibilityDeclarations.get()
            )

            var declarations: [[String: Any]] = []
            for decl in response.data {
                let attrs = decl.attributes
                var declDict: [String: Any] = [
                    "declarationId": decl.id
                ]
                if let df = attrs?.deviceFamily {
                    declDict["deviceFamily"] = df.rawValue
                }
                if let s = attrs?.state { declDict["state"] = s.rawValue }
                if let v = attrs?.isSupportsVoiceover {
                    declDict["supportsVoiceover"] = v
                }
                if let v = attrs?.isSupportsVoiceControl {
                    declDict["supportsVoiceControl"] = v
                }
                if let v = attrs?.isSupportsCaptions {
                    declDict["supportsCaptions"] = v
                }
                if let v = attrs?.isSupportsAudioDescriptions {
                    declDict["supportsAudioDescriptions"] = v
                }
                if let v = attrs?.isSupportsDarkInterface {
                    declDict["supportsDarkInterface"] = v
                }
                if let v = attrs?.isSupportsDifferentiateWithoutColorAlone {
                    declDict["supportsDifferentiateWithoutColorAlone"] = v
                }
                if let v = attrs?.isSupportsLargerText {
                    declDict["supportsLargerText"] = v
                }
                if let v = attrs?.isSupportsReducedMotion {
                    declDict["supportsReducedMotion"] = v
                }
                if let v = attrs?.isSupportsSufficientContrast {
                    declDict["supportsSufficientContrast"] = v
                }
                declarations.append(declDict)
            }

            let result: [String: Any] = [
                "appId": appId,
                "declarations": declarations,
                "count": declarations.count,
            ]
            let json = try JSONSerialization.data(
                withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            return .init(
                content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        // Update existing declaration
        if let declarationId = declarationId {
            var updateAttrs =
                AccessibilityDeclarationUpdateRequest.Data.Attributes()
            var changes: [String: Any] = [:]

            if let v = arguments?["supportsVoiceover"]?.boolValue {
                updateAttrs.isSupportsVoiceover = v
                changes["supportsVoiceover"] = v
            }
            if let v = arguments?["supportsVoiceControl"]?.boolValue {
                updateAttrs.isSupportsVoiceControl = v
                changes["supportsVoiceControl"] = v
            }
            if let v = arguments?["supportsCaptions"]?.boolValue {
                updateAttrs.isSupportsCaptions = v
                changes["supportsCaptions"] = v
            }
            if let v = arguments?["supportsAudioDescriptions"]?.boolValue {
                updateAttrs.isSupportsAudioDescriptions = v
                changes["supportsAudioDescriptions"] = v
            }
            if let v = arguments?["supportsDarkInterface"]?.boolValue {
                updateAttrs.isSupportsDarkInterface = v
                changes["supportsDarkInterface"] = v
            }
            if let v = arguments?["supportsDifferentiateWithoutColorAlone"]?
                .boolValue
            {
                updateAttrs.isSupportsDifferentiateWithoutColorAlone = v
                changes["supportsDifferentiateWithoutColorAlone"] = v
            }
            if let v = arguments?["supportsLargerText"]?.boolValue {
                updateAttrs.isSupportsLargerText = v
                changes["supportsLargerText"] = v
            }
            if let v = arguments?["supportsReducedMotion"]?.boolValue {
                updateAttrs.isSupportsReducedMotion = v
                changes["supportsReducedMotion"] = v
            }
            if let v = arguments?["supportsSufficientContrast"]?.boolValue {
                updateAttrs.isSupportsSufficientContrast = v
                changes["supportsSufficientContrast"] = v
            }
            if let v = arguments?["publish"]?.boolValue {
                updateAttrs.isPublish = v
                changes["publish"] = v
            }

            guard !changes.isEmpty else {
                return .init(
                    content: [
                        .text(
                            "Error: At least one accessibility feature must be provided for update"
                        )
                    ],
                    isError: true)
            }

            if dryRun {
                let result: [String: Any] = [
                    "status": "dry_run",
                    "action": "update",
                    "declarationId": declarationId,
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

            let request = AccessibilityDeclarationUpdateRequest(
                data: .init(
                    id: declarationId,
                    attributes: updateAttrs
                )
            )

            let response = try await client.send(
                Resources.v1.accessibilityDeclarations.id(declarationId).patch(
                    request)
            )

            let resultDict: [String: Any] = [
                "status": "updated",
                "declarationId": response.data.id,
                "changes": changes,
            ]
            let json = try JSONSerialization.data(
                withJSONObject: resultDict,
                options: [.prettyPrinted, .sortedKeys])
            return .init(
                content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        // Create new declaration
        guard let deviceFamilyStr = deviceFamilyStr else {
            return .init(
                content: [
                    .text(
                        "Error: deviceFamily is required when creating a new declaration (or provide declarationId to update)"
                    )
                ],
                isError: true)
        }

        guard let deviceFamily = DeviceFamily(rawValue: deviceFamilyStr) else {
            return .init(
                content: [
                    .text(
                        "Error: Invalid deviceFamily '\(deviceFamilyStr)'. Valid: IPHONE, IPAD, APPLE_TV, APPLE_WATCH, MAC, VISION"
                    )
                ],
                isError: true)
        }

        var createAttrs = AccessibilityDeclarationCreateRequest.Data.Attributes(
            deviceFamily: deviceFamily
        )
        var changes: [String: Any] = ["deviceFamily": deviceFamilyStr]

        if let v = arguments?["supportsVoiceover"]?.boolValue {
            createAttrs.isSupportsVoiceover = v
            changes["supportsVoiceover"] = v
        }
        if let v = arguments?["supportsVoiceControl"]?.boolValue {
            createAttrs.isSupportsVoiceControl = v
            changes["supportsVoiceControl"] = v
        }
        if let v = arguments?["supportsCaptions"]?.boolValue {
            createAttrs.isSupportsCaptions = v
            changes["supportsCaptions"] = v
        }
        if let v = arguments?["supportsAudioDescriptions"]?.boolValue {
            createAttrs.isSupportsAudioDescriptions = v
            changes["supportsAudioDescriptions"] = v
        }
        if let v = arguments?["supportsDarkInterface"]?.boolValue {
            createAttrs.isSupportsDarkInterface = v
            changes["supportsDarkInterface"] = v
        }
        if let v = arguments?["supportsDifferentiateWithoutColorAlone"]?
            .boolValue
        {
            createAttrs.isSupportsDifferentiateWithoutColorAlone = v
            changes["supportsDifferentiateWithoutColorAlone"] = v
        }
        if let v = arguments?["supportsLargerText"]?.boolValue {
            createAttrs.isSupportsLargerText = v
            changes["supportsLargerText"] = v
        }
        if let v = arguments?["supportsReducedMotion"]?.boolValue {
            createAttrs.isSupportsReducedMotion = v
            changes["supportsReducedMotion"] = v
        }
        if let v = arguments?["supportsSufficientContrast"]?.boolValue {
            createAttrs.isSupportsSufficientContrast = v
            changes["supportsSufficientContrast"] = v
        }

        if dryRun {
            let result: [String: Any] = [
                "status": "dry_run",
                "action": "create",
                "appId": appId,
                "values": changes,
            ]
            let json = try JSONSerialization.data(
                withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            return .init(
                content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        let request = AccessibilityDeclarationCreateRequest(
            data: .init(
                attributes: createAttrs,
                relationships: .init(
                    app: .init(data: .init(id: appId))
                )
            )
        )

        let response = try await client.send(
            Resources.v1.accessibilityDeclarations.post(request)
        )

        let resultDict: [String: Any] = [
            "status": "created",
            "declarationId": response.data.id,
            "appId": appId,
            "values": changes,
        ]
        let json = try JSONSerialization.data(
            withJSONObject: resultDict, options: [.prettyPrinted, .sortedKeys])
        return .init(
            content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
