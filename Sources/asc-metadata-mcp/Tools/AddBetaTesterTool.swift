import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum AddBetaTesterTool {
    static let tool = Tool(
        name: "add_beta_tester",
        description:
            "Add a tester to a TestFlight beta group by email. Creates the tester if they don't exist and adds them to the specified group.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "groupId": .object([
                    "type": "string",
                    "description": "Beta group ID to add the tester to",
                ]),
                "email": .object([
                    "type": "string",
                    "description": "Tester's email address",
                ]),
                "firstName": .object([
                    "type": "string",
                    "description": "Tester's first name (optional)",
                ]),
                "lastName": .object([
                    "type": "string",
                    "description": "Tester's last name (optional)",
                ]),
                "dryRun": .object([
                    "type": "boolean",
                    "description":
                        "Preview changes without applying (default: false)",
                    "default": .bool(false),
                ]),
            ]),
            "required": .array([.string("groupId"), .string("email")]),
        ])
    )

    static func handle(
        arguments: [String: Value]?,
        client: AppStoreConnectClient
    ) async throws -> CallTool.Result {
        guard let groupId = arguments?["groupId"]?.stringValue else {
            return .init(
                content: [.text("Error: groupId is required")], isError: true)
        }
        guard let email = arguments?["email"]?.stringValue else {
            return .init(
                content: [.text("Error: email is required")], isError: true)
        }

        let firstName = arguments?["firstName"]?.stringValue
        let lastName = arguments?["lastName"]?.stringValue
        let dryRun = arguments?["dryRun"]?.boolValue ?? false

        var preview: [String: Any] = [
            "groupId": groupId,
            "email": email,
        ]
        if let fn = firstName { preview["firstName"] = fn }
        if let ln = lastName { preview["lastName"] = ln }

        if dryRun {
            preview["status"] = "dry_run"
            preview["action"] = "add_tester_to_group"
            let json = try JSONSerialization.data(
                withJSONObject: preview,
                options: [.prettyPrinted, .sortedKeys])
            return .init(
                content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        // Create the tester with the group relationship.
        // The API will create the tester if they don't exist, or use the
        // existing tester if the email is already registered. The betaGroups
        // relationship ensures they are added to the specified group.
        let createRequest = BetaTesterCreateRequest(
            data: .init(
                attributes: .init(
                    firstName: firstName,
                    lastName: lastName,
                    email: email
                ),
                relationships: .init(
                    betaGroups: .init(
                        data: [.init(id: groupId)]
                    )
                )
            )
        )

        do {
            let response = try await client.send(
                Resources.v1.betaTesters.post(createRequest)
            )

            let tester = response.data
            var resultDict: [String: Any] = [
                "status": "added",
                "testerId": tester.id,
                "email": tester.attributes?.email ?? email,
                "groupId": groupId,
            ]
            if let fn = tester.attributes?.firstName {
                resultDict["firstName"] = fn
            }
            if let ln = tester.attributes?.lastName {
                resultDict["lastName"] = ln
            }
            if let state = tester.attributes?.state {
                resultDict["state"] = state.rawValue
            }
            if let inviteType = tester.attributes?.inviteType {
                resultDict["inviteType"] = inviteType.rawValue
            }

            let json = try JSONSerialization.data(
                withJSONObject: resultDict,
                options: [.prettyPrinted, .sortedKeys])
            return .init(
                content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        } catch {
            // If the tester already exists (409 conflict), try to find them
            // and add them to the group via the relationship endpoint
            let existingResponse = try await client.send(
                Resources.v1.betaTesters.get(
                    filterEmail: [email],
                    fieldsBetaTesters: [.firstName, .lastName, .email, .state]
                )
            )

            guard let existingTester = existingResponse.data.first else {
                // Re-throw the original error if we can't find the tester
                throw error
            }

            // Add existing tester to the group via the relationship endpoint
            let linkageRequest = BetaGroupBetaTestersLinkagesRequest(
                data: [.init(id: existingTester.id)]
            )

            _ = try await client.send(
                Resources.v1.betaGroups.id(groupId).relationships.betaTesters
                    .post(linkageRequest)
            )

            var resultDict: [String: Any] = [
                "status": "added",
                "note": "Existing tester added to group",
                "testerId": existingTester.id,
                "email": existingTester.attributes?.email ?? email,
                "groupId": groupId,
            ]
            if let fn = existingTester.attributes?.firstName {
                resultDict["firstName"] = fn
            }
            if let ln = existingTester.attributes?.lastName {
                resultDict["lastName"] = ln
            }
            if let state = existingTester.attributes?.state {
                resultDict["state"] = state.rawValue
            }

            let json = try JSONSerialization.data(
                withJSONObject: resultDict,
                options: [.prettyPrinted, .sortedKeys])
            return .init(
                content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }
    }
}
