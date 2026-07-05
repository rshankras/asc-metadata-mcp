import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum UpdatePhasedReleaseTool {
    static let tool = Tool(
        name: "update_phased_release",
        description:
            "Pause, resume, or complete a phased release.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "phasedReleaseId": .object([
                    "type": "string",
                    "description": "Phased release ID (returned by create_phased_release)",
                ]),
                "phasedReleaseState": .object([
                    "type": "string",
                    "description":
                        "New state: ACTIVE (resume rollout), PAUSED (pause rollout), COMPLETE (release to 100%)",
                    "enum": .array([
                        .string("ACTIVE"), .string("PAUSED"),
                        .string("COMPLETE"),
                    ]),
                ]),
                "dryRun": .object([
                    "type": "boolean",
                    "description":
                        "Preview changes without applying (default: false)",
                    "default": .bool(false),
                ]),
            ]),
            "required": .array([
                .string("phasedReleaseId"), .string("phasedReleaseState"),
            ]),
        ])
    )

    static func handle(
        arguments: [String: Value]?,
        client: AppStoreConnectClient
    ) async throws -> CallTool.Result {
        guard let phasedReleaseId = arguments?["phasedReleaseId"]?.stringValue
        else {
            return .init(
                content: [.text("Error: phasedReleaseId is required")],
                isError: true)
        }
        guard let stateStr = arguments?["phasedReleaseState"]?.stringValue else {
            return .init(
                content: [.text("Error: phasedReleaseState is required")],
                isError: true)
        }
        let dryRun = arguments?["dryRun"]?.boolValue ?? false

        // Map state string to enum
        let newState: PhasedReleaseState
        switch stateStr {
        case "ACTIVE": newState = .active
        case "PAUSED": newState = .paused
        case "COMPLETE": newState = .complete
        default:
            return .init(
                content: [
                    .text(
                        "Error: Invalid phasedReleaseState '\(stateStr)'. Must be ACTIVE, PAUSED, or COMPLETE."
                    )
                ],
                isError: true)
        }

        if dryRun {
            let result: [String: Any] = [
                "status": "dry_run",
                "action": "update_phased_release",
                "phasedReleaseId": phasedReleaseId,
                "requestedState": stateStr,
            ]
            let json = try JSONSerialization.data(
                withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            return .init(
                content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        // Apply update
        let request = AppStoreVersionPhasedReleaseUpdateRequest(
            data: .init(
                id: phasedReleaseId,
                attributes: .init(phasedReleaseState: newState)
            )
        )

        let response = try await client.send(
            Resources.v1.appStoreVersionPhasedReleases.id(phasedReleaseId)
                .patch(request)
        )
        let updated = response.data
        let attrs = updated.attributes

        var result: [String: Any] = [
            "status": "updated",
            "phasedReleaseId": updated.id,
            "phasedReleaseState": attrs?.phasedReleaseState?.rawValue ?? "",
        ]
        if let day = attrs?.currentDayNumber { result["currentDayNumber"] = day }
        if let startDate = attrs?.startDate {
            result["startDate"] = ISO8601DateFormatter().string(from: startDate)
        }
        if let pauseDuration = attrs?.totalPauseDuration {
            result["totalPauseDuration"] = pauseDuration
        }

        let json = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return .init(
            content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
