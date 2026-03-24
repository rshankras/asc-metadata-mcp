import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum ListReviewsTool {
    static let tool = Tool(
        name: "list_reviews",
        description:
            "List customer reviews for an app. Filter by rating, territory, or response status. Sort by rating or date.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "appId": .object(["type": "string", "description": "App Store app ID"]),
                "rating": .object([
                    "type": "string",
                    "description": "Filter by star rating (1-5)",
                    "enum": .array([
                        .string("1"), .string("2"), .string("3"), .string("4"), .string("5"),
                    ]),
                ]),
                "territory": .object([
                    "type": "string",
                    "description":
                        "Filter by territory code (e.g. USA, GBR, JPN, IND)",
                ]),
                "hasResponse": .object([
                    "type": "boolean",
                    "description":
                        "Filter for reviews with (true) or without (false) developer responses",
                ]),
                "sort": .object([
                    "type": "string",
                    "description": "Sort order for results",
                    "enum": .array([
                        .string("rating"), .string("-rating"),
                        .string("createdDate"), .string("-createdDate"),
                    ]),
                ]),
                "limit": .object([
                    "type": "integer",
                    "description": "Max number of reviews to return (default 25, max 200)",
                    "default": .int(25),
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

        let ratingFilter = arguments?["rating"]?.stringValue
        let territoryFilter = arguments?["territory"]?.stringValue
        let hasResponse = arguments?["hasResponse"]?.boolValue
        let sortStr = arguments?["sort"]?.stringValue
        let limit = arguments?["limit"]?.intValue ?? 25

        // Map sort
        typealias ReviewSort = Resources.V1.Apps.WithID.CustomerReviews.Sort
        var sort: [ReviewSort]? = nil
        if let sortStr = sortStr {
            switch sortStr {
            case "rating": sort = [.rating]
            case "-rating": sort = [.minusRating]
            case "createdDate": sort = [.createdDate]
            case "-createdDate": sort = [.minusCreatedDate]
            default: break
            }
        }

        // Map territory filter
        typealias FilterTerritory = Resources.V1.Apps.WithID.CustomerReviews.FilterTerritory
        var filterTerritory: [FilterTerritory]? = nil
        if let t = territoryFilter, let territory = FilterTerritory(rawValue: t) {
            filterTerritory = [territory]
        }

        // Map rating filter
        var filterRating: [String]? = nil
        if let r = ratingFilter {
            filterRating = [r]
        }

        let response = try await client.send(
            Resources.v1.apps.id(appId).customerReviews.get(
                filterTerritory: filterTerritory,
                filterRating: filterRating,
                isExistsPublishedResponse: hasResponse,
                sort: sort,
                fieldsCustomerReviews: [
                    .rating, .title, .body, .reviewerNickname, .createdDate, .territory,
                ],
                fieldsCustomerReviewResponses: [.responseBody, .lastModifiedDate, .state],
                limit: limit,
                include: [.response]
            )
        )

        let formatter = ISO8601DateFormatter()
        let includedResponses = response.included ?? []

        var reviews: [[String: Any]] = []
        for review in response.data {
            let attrs = review.attributes
            var reviewDict: [String: Any] = [
                "reviewId": review.id,
            ]
            if let rating = attrs?.rating { reviewDict["rating"] = rating }
            if let title = attrs?.title { reviewDict["title"] = title }
            if let body = attrs?.body { reviewDict["body"] = body }
            if let nickname = attrs?.reviewerNickname {
                reviewDict["reviewerNickname"] = nickname
            }
            if let date = attrs?.createdDate {
                reviewDict["createdDate"] = formatter.string(from: date)
            }
            if let territory = attrs?.territory {
                reviewDict["territory"] = territory.rawValue
            }

            // Find included response for this review
            if let responseRelId = review.relationships?.response?.data?.id {
                if let devResponse = includedResponses.first(where: { $0.id == responseRelId }) {
                    var respDict: [String: Any] = [
                        "responseId": devResponse.id,
                    ]
                    if let body = devResponse.attributes?.responseBody {
                        respDict["responseBody"] = body
                    }
                    if let date = devResponse.attributes?.lastModifiedDate {
                        respDict["lastModifiedDate"] = formatter.string(from: date)
                    }
                    if let state = devResponse.attributes?.state {
                        respDict["state"] = state.rawValue
                    }
                    reviewDict["developerResponse"] = respDict
                }
            }

            reviews.append(reviewDict)
        }

        let result: [String: Any] = [
            "totalReviews": reviews.count,
            "reviews": reviews,
        ]
        let json = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return .init(content: [.text(String(data: json, encoding: .utf8) ?? "[]")])
    }
}
