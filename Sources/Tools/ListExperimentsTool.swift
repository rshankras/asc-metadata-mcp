import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum ListExperimentsTool {
    static let tool = Tool(
        name: "list_experiments",
        description:
            "List product page optimization experiments (A/B tests) for an app.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "appId": .object(["type": "string", "description": "App Store app ID"]),
                "filterState": .object([
                    "type": "string",
                    "description": "Filter by experiment state",
                    "enum": .array([
                        .string("PREPARE_FOR_SUBMISSION"),
                        .string("READY_FOR_REVIEW"),
                        .string("WAITING_FOR_REVIEW"),
                        .string("IN_REVIEW"),
                        .string("ACCEPTED"),
                        .string("APPROVED"),
                        .string("REJECTED"),
                        .string("COMPLETED"),
                        .string("STOPPED"),
                    ]),
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
        let filterState = arguments?["filterState"]?.stringValue

        let response = try await client.send(
            Resources.v1.apps.id(appId).appStoreVersionExperimentsV2.get()
        )

        var filteredData = response.data
        if let stateStr = filterState {
            filteredData = filteredData.filter {
                $0.attributes?.state?.rawValue == stateStr
            }
        }

        let formatter = ISO8601DateFormatter()
        var experiments: [[String: Any]] = []

        for experiment in filteredData {
            let attrs = experiment.attributes
            var expDict: [String: Any] = [
                "experimentId": experiment.id,
            ]
            if let name = attrs?.name { expDict["name"] = name }
            if let platform = attrs?.platform {
                expDict["platform"] = platform.rawValue
            }
            if let tp = attrs?.trafficProportion {
                expDict["trafficProportion"] = tp
            }
            if let state = attrs?.state { expDict["state"] = state.rawValue }
            if let startDate = attrs?.startDate {
                expDict["startDate"] = formatter.string(from: startDate)
            }
            if let endDate = attrs?.endDate {
                expDict["endDate"] = formatter.string(from: endDate)
            }

            experiments.append(expDict)
        }

        let json = try JSONSerialization.data(
            withJSONObject: experiments, options: [.prettyPrinted, .sortedKeys])
        return .init(content: [.text(String(data: json, encoding: .utf8) ?? "[]")])
    }
}
