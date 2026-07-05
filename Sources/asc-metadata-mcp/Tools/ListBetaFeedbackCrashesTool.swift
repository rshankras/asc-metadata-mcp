import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum ListBetaFeedbackCrashesTool {
    static let tool = Tool(
        name: "list_beta_feedback_crashes",
        description:
            "List crash feedback submissions from TestFlight testers. Includes device info, tester comments, and build details. Filter by device model, OS version, platform, or build.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "appId": .object([
                    "type": "string",
                    "description": "App Store app ID",
                ]),
                "filterBuild": .object([
                    "type": "string",
                    "description": "Filter by build ID",
                ]),
                "filterDeviceModel": .object([
                    "type": "string",
                    "description":
                        "Filter by device model (e.g. 'iPhone15,2')",
                ]),
                "filterOsVersion": .object([
                    "type": "string",
                    "description": "Filter by OS version (e.g. '17.0')",
                ]),
                "filterPlatform": .object([
                    "type": "string",
                    "description": "Filter by platform",
                    "enum": .array([
                        .string("IOS"), .string("MAC_OS"),
                        .string("TV_OS"), .string("VISION_OS"),
                    ]),
                ]),
                "limit": .object([
                    "type": "integer",
                    "description":
                        "Maximum number of results (default: 50)",
                    "default": .int(50),
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

        let filterBuild = arguments?["filterBuild"]?.stringValue
        let filterDeviceModel = arguments?["filterDeviceModel"]?.stringValue
        let filterOsVersion = arguments?["filterOsVersion"]?.stringValue
        let filterPlatformStr = arguments?["filterPlatform"]?.stringValue
        let limit = arguments?["limit"]?.intValue ?? 50

        // Map platform filter
        typealias FilterAppPlatform = Resources.V1.Apps.WithID
            .BetaFeedbackCrashSubmissions.FilterAppPlatform
        var platformFilter: [FilterAppPlatform]?
        if let platformStr = filterPlatformStr {
            switch platformStr {
            case "IOS": platformFilter = [.iOS]
            case "MAC_OS": platformFilter = [.macOS]
            case "TV_OS": platformFilter = [.tvOS]
            case "VISION_OS": platformFilter = [.visionOS]
            default:
                return .init(
                    content: [
                        .text(
                            "Error: Invalid platform '\(platformStr)'. Must be one of: IOS, MAC_OS, TV_OS, VISION_OS"
                        )
                    ], isError: true)
            }
        }

        let response = try await client.send(
            Resources.v1.apps.id(appId).betaFeedbackCrashSubmissions.get(
                filterDeviceModel: filterDeviceModel.map { [$0] },
                filterOsVersion: filterOsVersion.map { [$0] },
                filterAppPlatform: platformFilter,
                filterBuild: filterBuild.map { [$0] },
                sort: [.minusCreatedDate],
                limit: limit,
                include: [.build, .tester]
            )
        )

        // Build lookup maps from included data
        var buildMap: [String: String] = [:]
        var testerMap: [String: [String: String]] = [:]
        for item in response.included ?? [] {
            switch item {
            case .build(let build):
                buildMap[build.id] = build.attributes?.version
            case .betaTester(let tester):
                testerMap[tester.id] = [
                    "firstName": tester.attributes?.firstName ?? "",
                    "lastName": tester.attributes?.lastName ?? "",
                    "email": tester.attributes?.email ?? "",
                ]
            }
        }

        let formatter = ISO8601DateFormatter()
        var submissions: [[String: Any]] = []

        for submission in response.data {
            let attrs = submission.attributes
            var dict: [String: Any] = [
                "id": submission.id
            ]
            if let v = attrs?.createdDate {
                dict["createdDate"] = formatter.string(from: v)
            }
            if let v = attrs?.comment { dict["comment"] = v }
            if let v = attrs?.email { dict["email"] = v }
            if let v = attrs?.deviceModel { dict["deviceModel"] = v }
            if let v = attrs?.osVersion { dict["osVersion"] = v }
            if let v = attrs?.locale { dict["locale"] = v }
            if let v = attrs?.architecture { dict["architecture"] = v }
            if let v = attrs?.connectionType {
                dict["connectionType"] = v.rawValue
            }
            if let v = attrs?.deviceFamily {
                dict["deviceFamily"] = v.rawValue
            }
            if let v = attrs?.batteryPercentage {
                dict["batteryPercentage"] = v
            }
            if let v = attrs?.buildBundleID { dict["buildBundleID"] = v }
            if let v = attrs?.appPlatform {
                dict["appPlatform"] = v.rawValue
            }

            // Resolve build version from included data
            if let buildId = submission.relationships?.build?.data?.id,
                let version = buildMap[buildId]
            {
                dict["buildVersion"] = version
            }

            // Resolve tester info from included data
            if let testerId = submission.relationships?.tester?.data?.id,
                let testerInfo = testerMap[testerId]
            {
                dict["tester"] = testerInfo
            }

            submissions.append(dict)
        }

        let result: [String: Any] = [
            "submissions": submissions,
            "count": submissions.count,
        ]
        let json = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return .init(
            content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
