import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum DeleteExperimentTool {
    static let tool = Tool(
        name: "delete_experiment",
        description:
            "Delete a product page optimization experiment.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "experimentId": .object([
                    "type": "string",
                    "description": "Experiment ID to delete",
                ]),
                "dryRun": .object([
                    "type": "boolean",
                    "description":
                        "Preview what will be deleted without deleting (default: false)",
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
        let dryRun = arguments?["dryRun"]?.boolValue ?? false

        // Fetch the experiment to show what's being deleted
        let currentResponse = try await client.send(
            Resources.v2.appStoreVersionExperiments.id(experimentId).get()
        )
        let experiment = currentResponse.data
        let attrs = experiment.attributes

        let formatter = ISO8601DateFormatter()
        var experimentInfo: [String: Any] = [
            "experimentId": experiment.id,
        ]
        if let name = attrs?.name { experimentInfo["name"] = name }
        if let platform = attrs?.platform {
            experimentInfo["platform"] = platform.rawValue
        }
        if let tp = attrs?.trafficProportion {
            experimentInfo["trafficProportion"] = tp
        }
        if let state = attrs?.state {
            experimentInfo["state"] = state.rawValue
        }
        if let startDate = attrs?.startDate {
            experimentInfo["startDate"] = formatter.string(from: startDate)
        }
        if let endDate = attrs?.endDate {
            experimentInfo["endDate"] = formatter.string(from: endDate)
        }

        if dryRun {
            let result: [String: Any] = [
                "status": "dry_run",
                "action": "delete",
                "experiment": experimentInfo,
            ]
            let json = try JSONSerialization.data(
                withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            return .init(
                content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        // Delete the experiment
        _ = try await client.send(
            Resources.v2.appStoreVersionExperiments.id(experimentId).delete
        )

        let result: [String: Any] = [
            "status": "deleted",
            "experiment": experimentInfo,
        ]
        let json = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return .init(
            content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
