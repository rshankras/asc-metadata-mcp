import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum GetReviewTool {
    static let tool = Tool(
        name: "get_review",
        description: "Get a single customer review with its developer response if any.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "reviewId": .object([
                    "type": "string",
                    "description": "Customer review ID",
                ]),
            ]),
            "required": .array([.string("reviewId")]),
        ])
    )

    static func handle(
        arguments: [String: Value]?,
        client: AppStoreConnectClient
    ) async throws -> CallTool.Result {
        guard let reviewId = arguments?["reviewId"]?.stringValue else {
            return .init(content: [.text("Error: reviewId is required")], isError: true)
        }

        let response = try await client.send(
            Resources.v1.customerReviews.id(reviewId).get(
                fieldsCustomerReviews: [
                    .rating, .title, .body, .reviewerNickname, .createdDate, .territory,
                ],
                fieldsCustomerReviewResponses: [.responseBody, .lastModifiedDate, .state],
                include: [.response]
            )
        )

        let formatter = ISO8601DateFormatter()
        let review = response.data
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

        // Check for included response
        if let included = response.included, let devResponse = included.first {
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

        let json = try JSONSerialization.data(
            withJSONObject: reviewDict, options: [.prettyPrinted, .sortedKeys])
        return .init(content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
