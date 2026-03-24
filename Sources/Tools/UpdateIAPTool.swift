import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum UpdateIAPTool {
    static let tool = Tool(
        name: "update_iap",
        description:
            "Update an in-app purchase's metadata. Shows old/new diff.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "iapId": .object([
                    "type": "string",
                    "description": "In-app purchase ID",
                ]),
                "name": .object([
                    "type": "string",
                    "description": "New reference name",
                ]),
                "reviewNote": .object([
                    "type": "string",
                    "description": "New review note for App Review",
                ]),
                "familySharable": .object([
                    "type": "boolean",
                    "description":
                        "Whether this IAP is available via Family Sharing",
                ]),
                "dryRun": .object([
                    "type": "boolean",
                    "description":
                        "Preview changes without applying (default: false)",
                    "default": .bool(false),
                ]),
            ]),
            "required": .array([.string("iapId")]),
        ])
    )

    static func handle(
        arguments: [String: Value]?,
        client: AppStoreConnectClient
    ) async throws -> CallTool.Result {
        guard let iapId = arguments?["iapId"]?.stringValue else {
            return .init(
                content: [.text("Error: iapId is required")], isError: true)
        }

        let newName = arguments?["name"]?.stringValue
        let newReviewNote = arguments?["reviewNote"]?.stringValue
        let newFamilySharable = arguments?["familySharable"]?.boolValue
        let dryRun = arguments?["dryRun"]?.boolValue ?? false

        // Ensure at least one field is being updated
        guard newName != nil || newReviewNote != nil || newFamilySharable != nil
        else {
            return .init(
                content: [
                    .text(
                        "Error: At least one field to update must be provided")
                ],
                isError: true)
        }

        // Fetch current IAP
        let currentResponse = try await client.send(
            Resources.v2.inAppPurchases.id(iapId).get()
        )
        let current = currentResponse.data
        let attrs = current.attributes

        // Build changes dict
        var changes: [String: Any] = [:]

        if let name = newName {
            changes["name"] = [
                "old": attrs?.name ?? "", "new": name,
            ]
        }
        if let reviewNote = newReviewNote {
            changes["reviewNote"] = [
                "old": attrs?.reviewNote ?? "", "new": reviewNote,
            ]
        }
        if let familySharable = newFamilySharable {
            changes["familySharable"] = [
                "old": attrs?.isFamilySharable ?? false, "new": familySharable,
            ]
        }

        if dryRun {
            let result: [String: Any] = [
                "status": "dry_run", "iapId": iapId, "changes": changes,
            ]
            let json = try JSONSerialization.data(
                withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            return .init(
                content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        // Apply update
        let updateRequest = InAppPurchaseV2UpdateRequest(
            data: .init(
                id: iapId,
                attributes: .init(
                    name: newName,
                    reviewNote: newReviewNote,
                    isFamilySharable: newFamilySharable
                )
            )
        )

        _ = try await client.send(
            Resources.v2.inAppPurchases.id(iapId).patch(updateRequest)
        )

        let result: [String: Any] = [
            "status": "updated", "iapId": iapId, "changes": changes,
        ]
        let json = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return .init(
            content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
