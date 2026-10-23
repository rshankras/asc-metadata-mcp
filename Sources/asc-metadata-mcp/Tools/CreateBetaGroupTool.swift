import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum CreateBetaGroupTool {
    static let tool = Tool(
        name: "create_beta_group",
        description:
            "Create a new TestFlight beta group for an app.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "appId": .object([
                    "type": "string",
                    "description": "App Store app ID",
                ]),
                "name": .object([
                    "type": "string",
                    "description": "Name for the beta group",
                ]),
                "isInternalGroup": .object([
                    "type": "boolean",
                    "description":
                        "Whether this is an internal group (default: false for external)",
                ]),
                "publicLinkEnabled": .object([
                    "type": "boolean",
                    "description": "Enable public link for joining",
                ]),
                "publicLinkLimit": .object([
                    "type": "integer",
                    "description": "Maximum number of testers via public link",
                ]),
                "publicLinkLimitEnabled": .object([
                    "type": "boolean",
                    "description": "Whether the public link limit is enabled",
                ]),
                "feedbackEnabled": .object([
                    "type": "boolean",
                    "description": "Enable feedback from testers",
                ]),
                "dryRun": .object([
                    "type": "boolean",
                    "description":
                        "Preview changes without applying (default: false)",
                    "default": .bool(false),
                ]),
            ]),
            "required": .array([.string("appId"), .string("name")]),
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
        guard let name = arguments?["name"]?.stringValue else {
            return .init(
                content: [.text("Error: name is required")], isError: true)
        }

        let isInternalGroup = arguments?["isInternalGroup"]?.boolValue
        let publicLinkEnabled = arguments?["publicLinkEnabled"]?.boolValue
        let publicLinkLimit = arguments?["publicLinkLimit"]?.intValue
        let publicLinkLimitEnabled =
            arguments?["publicLinkLimitEnabled"]?.boolValue
        let feedbackEnabled = arguments?["feedbackEnabled"]?.boolValue
        let dryRun = arguments?["dryRun"]?.boolValue ?? false

        var preview: [String: Any] = [
            "appId": appId,
            "name": name,
        ]
        if let v = isInternalGroup { preview["isInternalGroup"] = v }
        if let v = publicLinkEnabled { preview["publicLinkEnabled"] = v }
        if let v = publicLinkLimit { preview["publicLinkLimit"] = v }
        if let v = publicLinkLimitEnabled {
            preview["publicLinkLimitEnabled"] = v
        }
        if let v = feedbackEnabled { preview["feedbackEnabled"] = v }

        if dryRun {
            preview["status"] = "dry_run"
            let json = try JSONSerialization.data(
                withJSONObject: preview,
                options: [.prettyPrinted, .sortedKeys])
            return .init(
                content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        let createAttrs = BetaGroupCreateRequest.Data.Attributes(
            name: name,
            isInternalGroup: isInternalGroup,
            isPublicLinkEnabled: publicLinkEnabled,
            isPublicLinkLimitEnabled: publicLinkLimitEnabled,
            publicLinkLimit: publicLinkLimit,
            isFeedbackEnabled: feedbackEnabled
        )

        let request = BetaGroupCreateRequest(
            data: .init(
                attributes: createAttrs,
                relationships: .init(
                    app: .init(data: .init(id: appId))
                )
            )
        )

        let response = try await client.send(
            Resources.v1.betaGroups.post(request)
        )

        let created = response.data
        var resultDict: [String: Any] = [
            "status": "created",
            "groupId": created.id,
            "name": created.attributes?.name ?? name,
            "appId": appId,
        ]
        if let v = created.attributes?.isInternalGroup {
            resultDict["isInternalGroup"] = v
        }
        if let v = created.attributes?.isPublicLinkEnabled {
            resultDict["publicLinkEnabled"] = v
        }
        if let v = created.attributes?.publicLink {
            resultDict["publicLink"] = v
        }
        if let v = created.attributes?.isFeedbackEnabled {
            resultDict["feedbackEnabled"] = v
        }

        let json = try JSONSerialization.data(
            withJSONObject: resultDict, options: [.prettyPrinted, .sortedKeys])
        return .init(
            content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
