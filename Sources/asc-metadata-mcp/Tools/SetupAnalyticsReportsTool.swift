import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum SetupAnalyticsReportsTool {
    static let tool = Tool(
        name: "setup_analytics_reports",
        description:
            "Set up ongoing analytics report collection for an app. This is a one-time prerequisite before downloading analytics data with get_analytics_report. Idempotent — if already set up, returns current status.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "appId": .object(["type": "string", "description": "App Store app ID"])
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

        // Check for existing ONGOING report request
        let existingResponse = try await client.send(
            Resources.v1.apps.id(appId).analyticsReportRequests.get(
                filterAccessType: [.ongoing],
                limit: 10
            )
        )

        // Find an active (non-stopped) request
        let activeRequest = existingResponse.data.first {
            $0.attributes?.isStoppedDueToInactivity != true
        }

        if let activeRequest {
            // Already set up — return status and available reports
            let reportsResponse = try await client.send(
                Resources.v1.analyticsReportRequests.id(activeRequest.id).reports.get(
                    limit: 50
                )
            )

            var reportsByCategory: [String: [String]] = [:]
            for report in reportsResponse.data {
                let category = report.attributes?.category?.rawValue ?? "unknown"
                let name = report.attributes?.name ?? "unnamed"
                reportsByCategory[category, default: []].append(name)
            }

            let result: [String: Any] = [
                "status": "already_active",
                "requestId": activeRequest.id,
                "accessType": activeRequest.attributes?.accessType?.rawValue ?? "unknown",
                "availableReportCategories": reportsByCategory,
                "totalReports": reportsResponse.data.count,
                "message":
                    "Analytics report collection is already active. Use get_analytics_report to download data.",
            ]

            let json = try JSONSerialization.data(
                withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            return .init(content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        // No active request — create one
        let createRequest = AnalyticsReportRequestCreateRequest(
            data: .init(
                type: .analyticsReportRequests,
                attributes: .init(accessType: .ongoing),
                relationships: .init(
                    app: .init(data: .init(type: .apps, id: appId))
                )
            )
        )

        let createResponse = try await client.send(
            Resources.v1.analyticsReportRequests.post(createRequest)
        )

        let result: [String: Any] = [
            "status": "created",
            "requestId": createResponse.data.id,
            "accessType": createResponse.data.attributes?.accessType?.rawValue ?? "ongoing",
            "message":
                "Analytics report collection has been set up. Data will be available within 24-48 hours. Use get_analytics_report to download data once available.",
        ]

        let json = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        return .init(content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
    }
}
