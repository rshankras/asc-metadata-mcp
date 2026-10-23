import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum ListBetaGroupsTool {
    static let tool = Tool(
        name: "list_beta_groups",
        description:
            "List TestFlight beta groups. Optionally filter by app, name, or internal/external type.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "appId": .object([
                    "type": "string",
                    "description": "Filter by app ID",
                ]),
                "filterName": .object([
                    "type": "string",
                    "description": "Filter by group name",
                ]),
                "filterIsInternal": .object([
                    "type": "boolean",
                    "description":
                        "Filter by internal group (true) or external group (false)",
                ]),
            ]),
        ])
    )

    static func handle(
        arguments: [String: Value]?,
        client: AppStoreConnectClient
    ) async throws -> CallTool.Result {
        let appId = arguments?["appId"]?.stringValue
        let filterName = arguments?["filterName"]?.stringValue
        let filterIsInternal = arguments?["filterIsInternal"]?.boolValue

        let response = try await client.send(
            Resources.v1.betaGroups.get(
                filterName: filterName.map { [$0] },
                filterIsInternalGroup: filterIsInternal.map {
                    [$0 ? "true" : "false"]
                },
                filterApp: appId.map { [$0] },
                fieldsBetaGroups: [
                    .name, .createdDate, .isInternalGroup, .hasAccessToAllBuilds,
                    .publicLinkEnabled, .publicLinkID, .publicLinkLimitEnabled,
                    .publicLinkLimit, .publicLink, .feedbackEnabled,
                ],
                limit: 200
            )
        )

        let formatter = ISO8601DateFormatter()
        var groups: [[String: Any]] = []

        for group in response.data {
            let attrs = group.attributes
            var groupDict: [String: Any] = [
                "groupId": group.id,
                "name": attrs?.name ?? "",
            ]
            if let v = attrs?.isInternalGroup {
                groupDict["isInternalGroup"] = v
            }
            if let v = attrs?.createdDate {
                groupDict["createdDate"] = formatter.string(from: v)
            }
            if let v = attrs?.hasAccessToAllBuilds {
                groupDict["hasAccessToAllBuilds"] = v
            }
            if let v = attrs?.isPublicLinkEnabled {
                groupDict["publicLinkEnabled"] = v
            }
            if let v = attrs?.publicLink { groupDict["publicLink"] = v }
            if let v = attrs?.publicLinkID { groupDict["publicLinkId"] = v }
            if let v = attrs?.isPublicLinkLimitEnabled {
                groupDict["publicLinkLimitEnabled"] = v
            }
            if let v = attrs?.publicLinkLimit {
                groupDict["publicLinkLimit"] = v
            }
            if let v = attrs?.isFeedbackEnabled {
                groupDict["feedbackEnabled"] = v
            }

            groups.append(groupDict)
        }

        let result: [String: Any] = [
            "groups": groups,
            "count": groups.count,
        ]
        let json = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return .init(
            content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
