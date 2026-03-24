import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum UpdateExperimentTool {
    static let tool = Tool(
        name: "update_experiment",
        description:
            "Update an experiment's name, traffic proportion, or start/stop it. Shows old/new diff.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "experimentId": .object([
                    "type": "string",
                    "description": "Experiment ID",
                ]),
                "name": .object([
                    "type": "string",
                    "description": "New name for the experiment",
                ]),
                "trafficProportion": .object([
                    "type": "integer",
                    "description":
                        "New traffic proportion percentage (1-100)",
                ]),
                "started": .object([
                    "type": "boolean",
                    "description":
                        "Set to true to start the experiment",
                ]),
                "dryRun": .object([
                    "type": "boolean",
                    "description":
                        "Preview changes without applying (default: false)",
                    "default": .bool(false),
                ]),
            ]),
            "required": .array([.string("experimentId")]),
        ])
    )

    static func handle(
        arguments: [String: Value]?,
        client: AppStoreConnectClient
    ) async throws -> CallTool.Result {
        guard let experimentId = arguments?["experimentId"]?.stringValue else {
            return .init(
                content: [.text("Error: experimentId is required")], isError: true)
        }

        let newName = arguments?["name"]?.stringValue
        let newTrafficProportion = arguments?["trafficProportion"]?.intValue
        let started = arguments?["started"]?.boolValue
        let dryRun = arguments?["dryRun"]?.boolValue ?? false

        // Ensure at least one field is being updated
        guard newName != nil || newTrafficProportion != nil || started != nil else {
            return .init(
                content: [
                    .text(
                        "Error: At least one field to update must be provided (name, trafficProportion, or started)"
                    )
                ],
                isError: true)
        }

        // Validate traffic proportion if provided
        if let tp = newTrafficProportion, (tp < 1 || tp > 100) {
            return .init(
                content: [
                    .text("Error: trafficProportion must be between 1 and 100")
                ],
                isError: true)
        }

        // Fetch current experiment
        let currentResponse = try await client.send(
            Resources.v2.appStoreVersionExperiments.id(experimentId).get()
        )
        let current = currentResponse.data
        let attrs = current.attributes

        // Build changes dict
        var changes: [String: Any] = [:]

        if let newName = newName {
            changes["name"] = [
                "old": attrs?.name ?? "", "new": newName,
            ]
        }
        if let tp = newTrafficProportion {
            changes["trafficProportion"] = [
                "old": attrs?.trafficProportion ?? 0, "new": tp,
            ]
        }
        if let started = started {
            changes["started"] = [
                "old": false, "new": started,
            ]
        }

        if dryRun {
            let result: [String: Any] = [
                "status": "dry_run",
                "experimentId": experimentId,
                "changes": changes,
            ]
            let json = try JSONSerialization.data(
                withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            return .init(
                content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        // Apply update
        let updateRequest = AppStoreVersionExperimentV2UpdateRequest(
            data: .init(
                id: experimentId,
                attributes: .init(
                    name: newName,
                    trafficProportion: newTrafficProportion,
                    isStarted: started
                )
            )
        )

        _ = try await client.send(
            Resources.v2.appStoreVersionExperiments.id(experimentId).patch(
                updateRequest)
        )

        let result: [String: Any] = [
            "status": "updated",
            "experimentId": experimentId,
            "changes": changes,
        ]
        let json = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return .init(
            content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
