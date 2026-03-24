import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum DeleteReviewResponseTool {
    static let tool = Tool(
        name: "delete_review_response",
        description:
            "Delete a developer response to a customer review. Fetches response details before deleting for confirmation.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "responseId": .object([
                    "type": "string",
                    "description": "Developer response ID to delete",
                ]),
                "dryRun": .object([
                    "type": "boolean",
                    "description":
                        "Preview what will be deleted without deleting (default: false)",
                    "default": .bool(false),
                ]),
            ]),
            "required": .array([.string("responseId")]),
        ])
    )

    static func handle(
        arguments: [String: Value]?,
        client: AppStoreConnectClient
    ) async throws -> CallTool.Result {
        guard let responseId = arguments?["responseId"]?.stringValue else {
            return .init(
                content: [.text("Error: responseId is required")], isError: true)
        }
        let dryRun = arguments?["dryRun"]?.boolValue ?? false

        // Fetch the response to show what's being deleted
        let currentResponse = try await client.send(
            Resources.v1.customerReviewResponses.id(responseId).get(
                fieldsCustomerReviewResponses: [.responseBody, .lastModifiedDate, .state]
            )
        )

        let devResponse = currentResponse.data
        var responseInfo: [String: Any] = [
            "responseId": devResponse.id,
        ]
        if let body = devResponse.attributes?.responseBody {
            responseInfo["responseBody"] = body
        }
        if let date = devResponse.attributes?.lastModifiedDate {
            let formatter = ISO8601DateFormatter()
            responseInfo["lastModifiedDate"] = formatter.string(from: date)
        }
        if let state = devResponse.attributes?.state {
            responseInfo["state"] = state.rawValue
        }

        if dryRun {
            let result: [String: Any] = [
                "status": "dry_run",
                "action": "delete",
                "response": responseInfo,
            ]
            let json = try JSONSerialization.data(
                withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            return .init(
                content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        // Delete the response
        _ = try await client.send(
            Resources.v1.customerReviewResponses.id(responseId).delete
        )

        let result: [String: Any] = [
            "status": "deleted",
            "response": responseInfo,
        ]
        let json = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return .init(
            content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
