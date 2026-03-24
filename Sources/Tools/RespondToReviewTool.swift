import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum RespondToReviewTool {
    static let tool = Tool(
        name: "respond_to_review",
        description:
            "Create a developer response to a customer review. Shows the review context alongside the proposed response.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "reviewId": .object([
                    "type": "string",
                    "description": "Customer review ID to respond to",
                ]),
                "responseBody": .object([
                    "type": "string",
                    "description": "Developer response text (max 5970 chars)",
                ]),
                "dryRun": .object([
                    "type": "boolean",
                    "description":
                        "Preview the response without posting (default: false)",
                    "default": .bool(false),
                ]),
            ]),
            "required": .array([.string("reviewId"), .string("responseBody")]),
        ])
    )

    static func handle(
        arguments: [String: Value]?,
        client: AppStoreConnectClient
    ) async throws -> CallTool.Result {
        guard let reviewId = arguments?["reviewId"]?.stringValue else {
            return .init(content: [.text("Error: reviewId is required")], isError: true)
        }
        guard let responseBody = arguments?["responseBody"]?.stringValue else {
            return .init(
                content: [.text("Error: responseBody is required")], isError: true)
        }
        let dryRun = arguments?["dryRun"]?.boolValue ?? false

        // Validate response length
        let (valid, error) = CharLimitValidator.validate(
            responseBody, field: "Response", maxChars: 5970)
        if !valid {
            return .init(content: [.text("Error: \(error!)")], isError: true)
        }

        // Fetch the review for context
        let reviewResponse = try await client.send(
            Resources.v1.customerReviews.id(reviewId).get(
                fieldsCustomerReviews: [
                    .rating, .title, .body, .reviewerNickname, .createdDate, .territory,
                ],
                fieldsCustomerReviewResponses: [.responseBody, .lastModifiedDate, .state],
                include: [.response]
            )
        )

        let formatter = ISO8601DateFormatter()
        let review = reviewResponse.data
        let attrs = review.attributes

        var reviewContext: [String: Any] = [
            "reviewId": review.id,
        ]
        if let rating = attrs?.rating { reviewContext["rating"] = rating }
        if let title = attrs?.title { reviewContext["title"] = title }
        if let body = attrs?.body { reviewContext["body"] = body }
        if let nickname = attrs?.reviewerNickname {
            reviewContext["reviewerNickname"] = nickname
        }
        if let date = attrs?.createdDate {
            reviewContext["createdDate"] = formatter.string(from: date)
        }
        if let territory = attrs?.territory {
            reviewContext["territory"] = territory.rawValue
        }

        // Check if there's already a response
        if let included = reviewResponse.included, let existing = included.first {
            var existingDict: [String: Any] = [
                "responseId": existing.id,
            ]
            if let body = existing.attributes?.responseBody {
                existingDict["responseBody"] = body
            }
            reviewContext["existingResponse"] = existingDict
        }

        var resultDict: [String: Any] = [
            "review": reviewContext,
            "proposedResponse": responseBody,
            "responseLength": "\(responseBody.count)/5970",
        ]

        if dryRun {
            resultDict["status"] = "dry_run"
            let json = try JSONSerialization.data(
                withJSONObject: resultDict, options: [.prettyPrinted, .sortedKeys])
            return .init(
                content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        // Create the response
        let request = CustomerReviewResponseV1CreateRequest(
            data: .init(
                attributes: .init(responseBody: responseBody),
                relationships: .init(
                    review: .init(data: .init(id: reviewId))
                )
            )
        )

        let createResponse = try await client.send(
            Resources.v1.customerReviewResponses.post(request)
        )

        resultDict["status"] = "posted"
        resultDict["responseId"] = createResponse.data.id
        if let state = createResponse.data.attributes?.state {
            resultDict["responseState"] = state.rawValue
        }

        let json = try JSONSerialization.data(
            withJSONObject: resultDict, options: [.prettyPrinted, .sortedKeys])
        return .init(
            content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
