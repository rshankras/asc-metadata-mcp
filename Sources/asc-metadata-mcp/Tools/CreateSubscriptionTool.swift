import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum CreateSubscriptionTool {
    static let tool = Tool(
        name: "create_subscription",
        description: "Create a new subscription within a subscription group.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "groupId": .object([
                    "type": "string",
                    "description": "Subscription group ID",
                ]),
                "name": .object([
                    "type": "string",
                    "description": "Display name of the subscription",
                ]),
                "productId": .object([
                    "type": "string",
                    "description": "Product identifier for the subscription",
                ]),
                "subscriptionPeriod": .object([
                    "type": "string",
                    "description": "Subscription duration period",
                    "enum": .array([
                        .string("ONE_WEEK"), .string("ONE_MONTH"),
                        .string("TWO_MONTHS"), .string("THREE_MONTHS"),
                        .string("SIX_MONTHS"), .string("ONE_YEAR"),
                    ]),
                ]),
                "reviewNote": .object([
                    "type": "string",
                    "description": "Note for App Review about this subscription",
                ]),
                "familySharable": .object([
                    "type": "boolean",
                    "description": "Whether the subscription supports Family Sharing",
                ]),
                "groupLevel": .object([
                    "type": "integer",
                    "description":
                        "Level of service within the subscription group (1 is highest)",
                ]),
                "dryRun": .object([
                    "type": "boolean",
                    "description":
                        "Preview changes without applying (default: false)",
                    "default": .bool(false),
                ]),
            ]),
            "required": .array([
                .string("groupId"), .string("name"), .string("productId"),
            ]),
        ])
    )

    static func handle(
        arguments: [String: Value]?,
        client: AppStoreConnectClient
    ) async throws -> CallTool.Result {
        guard let groupId = arguments?["groupId"]?.stringValue else {
            return .init(content: [.text("Error: groupId is required")], isError: true)
        }
        guard let name = arguments?["name"]?.stringValue else {
            return .init(content: [.text("Error: name is required")], isError: true)
        }
        guard let productId = arguments?["productId"]?.stringValue else {
            return .init(
                content: [.text("Error: productId is required")], isError: true)
        }

        let periodStr = arguments?["subscriptionPeriod"]?.stringValue
        let reviewNote = arguments?["reviewNote"]?.stringValue
        let familySharable = arguments?["familySharable"]?.boolValue
        let groupLevel = arguments?["groupLevel"]?.intValue
        let dryRun = arguments?["dryRun"]?.boolValue ?? false

        // Map subscription period
        var subscriptionPeriod:
            SubscriptionCreateRequest.Data.Attributes.SubscriptionPeriod? = nil
        if let periodStr = periodStr {
            switch periodStr {
            case "ONE_WEEK": subscriptionPeriod = .oneWeek
            case "ONE_MONTH": subscriptionPeriod = .oneMonth
            case "TWO_MONTHS": subscriptionPeriod = .twoMonths
            case "THREE_MONTHS": subscriptionPeriod = .threeMonths
            case "SIX_MONTHS": subscriptionPeriod = .sixMonths
            case "ONE_YEAR": subscriptionPeriod = .oneYear
            default:
                return .init(
                    content: [
                        .text(
                            "Error: Invalid subscriptionPeriod '\(periodStr)'. Use ONE_WEEK, ONE_MONTH, TWO_MONTHS, THREE_MONTHS, SIX_MONTHS, or ONE_YEAR."
                        )
                    ],
                    isError: true)
            }
        }

        var resultDict: [String: Any] = [
            "groupId": groupId,
            "name": name,
            "productId": productId,
        ]
        if let p = periodStr { resultDict["subscriptionPeriod"] = p }
        if let rn = reviewNote { resultDict["reviewNote"] = rn }
        if let fs = familySharable { resultDict["familySharable"] = fs }
        if let gl = groupLevel { resultDict["groupLevel"] = gl }

        if dryRun {
            resultDict["status"] = "dry_run"
            let json = try JSONSerialization.data(
                withJSONObject: resultDict,
                options: [.prettyPrinted, .sortedKeys])
            return .init(
                content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        let request = SubscriptionCreateRequest(
            data: .init(
                attributes: .init(
                    name: name,
                    productID: productId,
                    isFamilySharable: familySharable,
                    subscriptionPeriod: subscriptionPeriod,
                    reviewNote: reviewNote,
                    groupLevel: groupLevel
                ),
                relationships: .init(
                    group: .init(data: .init(id: groupId))
                )
            )
        )

        let response = try await client.send(
            Resources.v1.subscriptions.post(request)
        )

        resultDict["status"] = "created"
        resultDict["subscriptionId"] = response.data.id

        let json = try JSONSerialization.data(
            withJSONObject: resultDict, options: [.prettyPrinted, .sortedKeys])
        return .init(
            content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
