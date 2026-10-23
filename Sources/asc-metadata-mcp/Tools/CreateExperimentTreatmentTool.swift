import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum CreateExperimentTreatmentTool {
    static let tool = Tool(
        name: "create_experiment_treatment",
        description:
            "Add a treatment variant to a product page optimization experiment.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "experimentId": .object([
                    "type": "string",
                    "description": "Experiment ID to add the treatment to",
                ]),
                "name": .object([
                    "type": "string",
                    "description": "Name of the treatment variant",
                ]),
                "appIconName": .object([
                    "type": "string",
                    "description":
                        "App icon name for this treatment (optional)",
                ]),
                "dryRun": .object([
                    "type": "boolean",
                    "description":
                        "Preview changes without applying (default: false)",
                    "default": .bool(false),
                ]),
            ]),
            "required": .array([.string("experimentId"), .string("name")]),
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
        guard let name = arguments?["name"]?.stringValue else {
            return .init(
                content: [.text("Error: name is required")], isError: true)
        }
        let appIconName = arguments?["appIconName"]?.stringValue
        let dryRun = arguments?["dryRun"]?.boolValue ?? false

        var resultDict: [String: Any] = [
            "experimentId": experimentId,
            "name": name,
        ]
        if let iconName = appIconName { resultDict["appIconName"] = iconName }

        if dryRun {
            resultDict["status"] = "dry_run"
            let json = try JSONSerialization.data(
                withJSONObject: resultDict,
                options: [.prettyPrinted, .sortedKeys])
            return .init(
                content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        // Create the treatment
        let request = AppStoreVersionExperimentTreatmentCreateRequest(
            data: .init(
                attributes: .init(
                    name: name,
                    appIconName: appIconName
                ),
                relationships: .init(
                    appStoreVersionExperimentV2: .init(
                        data: .init(id: experimentId)
                    )
                )
            )
        )

        let response = try await client.send(
            Resources.v1.appStoreVersionExperimentTreatments.post(request)
        )
        let created = response.data
        resultDict["status"] = "created"
        resultDict["treatmentId"] = created.id

        let json = try JSONSerialization.data(
            withJSONObject: resultDict, options: [.prettyPrinted, .sortedKeys])
        return .init(
            content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
