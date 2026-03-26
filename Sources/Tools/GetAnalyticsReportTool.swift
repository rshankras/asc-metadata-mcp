import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum GetAnalyticsReportTool {
    static let tool = Tool(
        name: "get_analytics_report",
        description:
            "Download analytics report data for an app. Requires setup_analytics_reports to be run first. If no reportName is specified, lists available reports for discovery. Categories: APP_USAGE, APP_STORE_ENGAGEMENT, COMMERCE, FRAMEWORK_USAGE, PERFORMANCE.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "appId": .object(["type": "string", "description": "App Store app ID"]),
                "category": .object([
                    "type": "string",
                    "description": "Report category (default: APP_STORE_ENGAGEMENT)",
                    "enum": .array([
                        .string("APP_USAGE"), .string("APP_STORE_ENGAGEMENT"),
                        .string("COMMERCE"), .string("FRAMEWORK_USAGE"),
                        .string("PERFORMANCE"),
                    ]),
                    "default": "APP_STORE_ENGAGEMENT",
                ]),
                "reportName": .object([
                    "type": "string",
                    "description":
                        "Specific report name to download. If omitted, lists available reports in the category.",
                ]),
                "granularity": .object([
                    "type": "string",
                    "description": "Data granularity (default: DAILY)",
                    "enum": .array([
                        .string("DAILY"), .string("WEEKLY"), .string("MONTHLY"),
                    ]),
                    "default": "DAILY",
                ]),
                "date": .object([
                    "type": "string",
                    "description":
                        "Processing date in YYYY-MM-DD format. If omitted, uses the most recent available date.",
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

        let categoryStr = arguments?["category"]?.stringValue ?? "APP_STORE_ENGAGEMENT"
        let reportName = arguments?["reportName"]?.stringValue
        let granularityStr = arguments?["granularity"]?.stringValue ?? "DAILY"
        let dateStr = arguments?["date"]?.stringValue

        // Map category string to filter enum
        typealias FilterCategory =
            Resources.V1.AnalyticsReportRequests.WithID.Reports.FilterCategory
        let categoryFilter: FilterCategory
        switch categoryStr {
        case "APP_USAGE": categoryFilter = .appUsage
        case "APP_STORE_ENGAGEMENT": categoryFilter = .appStoreEngagement
        case "COMMERCE": categoryFilter = .commerce
        case "FRAMEWORK_USAGE": categoryFilter = .frameworkUsage
        case "PERFORMANCE": categoryFilter = .performance
        default:
            return .init(
                content: [
                    .text(
                        "Error: Invalid category '\(categoryStr)'. Must be one of: APP_USAGE, APP_STORE_ENGAGEMENT, COMMERCE, FRAMEWORK_USAGE, PERFORMANCE"
                    )
                ], isError: true)
        }

        // Map granularity string to filter enum
        typealias FilterGranularity =
            Resources.V1.AnalyticsReports.WithID.Instances.FilterGranularity
        let granularityFilter: FilterGranularity
        switch granularityStr {
        case "DAILY": granularityFilter = .daily
        case "WEEKLY": granularityFilter = .weekly
        case "MONTHLY": granularityFilter = .monthly
        default:
            return .init(
                content: [
                    .text(
                        "Error: Invalid granularity '\(granularityStr)'. Must be one of: DAILY, WEEKLY, MONTHLY"
                    )
                ], isError: true)
        }

        // Step 1: Find ONGOING report request for this app
        let requestsResponse = try await client.send(
            Resources.v1.apps.id(appId).analyticsReportRequests.get(
                filterAccessType: [.ongoing],
                limit: 10
            )
        )

        guard
            let reportRequest = requestsResponse.data.first(where: {
                $0.attributes?.isStoppedDueToInactivity != true
            })
        else {
            return .init(
                content: [
                    .text(
                        "Error: No active analytics report request found. Run setup_analytics_reports first to enable analytics collection."
                    )
                ], isError: true)
        }

        // Step 2: List reports filtered by category
        let reportsResponse = try await client.send(
            Resources.v1.analyticsReportRequests.id(reportRequest.id).reports.get(
                filterCategory: [categoryFilter],
                limit: 50
            )
        )

        if reportsResponse.data.isEmpty {
            return .init(
                content: [
                    .text(
                        "No reports available in category '\(categoryStr)'. Data may still be processing (can take 24-48 hours after setup)."
                    )
                ])
        }

        // If no reportName specified, list available reports for discovery
        guard let reportName else {
            let availableReports = reportsResponse.data.map { report in
                [
                    "name": report.attributes?.name ?? "unnamed",
                    "category": report.attributes?.category?.rawValue ?? "unknown",
                    "reportId": report.id,
                ] as [String: String]
            }
            let result: [String: Any] = [
                "appId": appId,
                "category": categoryStr,
                "availableReports": availableReports,
                "message":
                    "Specify a reportName parameter to download a specific report.",
            ]
            let json = try JSONSerialization.data(
                withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            return .init(content: [.text(String(data: json, encoding: .utf8) ?? "{}")])
        }

        // Step 3: Find the matching report by name
        guard
            let report = reportsResponse.data.first(where: {
                $0.attributes?.name == reportName
            })
        else {
            let available = reportsResponse.data.compactMap { $0.attributes?.name }
            return .init(
                content: [
                    .text(
                        "Error: Report '\(reportName)' not found in category '\(categoryStr)'. Available reports: \(available.joined(separator: ", "))"
                    )
                ], isError: true)
        }

        // Step 4: Get report instances
        var dateFilter: [String]? = nil
        if let dateStr {
            dateFilter = [dateStr]
        }

        let instancesResponse = try await client.send(
            Resources.v1.analyticsReports.id(report.id).instances.get(
                filterGranularity: [granularityFilter],
                filterProcessingDate: dateFilter,
                limit: 1
            )
        )

        guard let instance = instancesResponse.data.first else {
            return .init(
                content: [
                    .text(
                        "No report instances found for granularity '\(granularityStr)'\(dateStr.map { " and date '\($0)'" } ?? ""). Try a different date or granularity."
                    )
                ], isError: true)
        }

        // Step 5: Get segments (download URLs)
        let segmentsResponse = try await client.send(
            Resources.v1.analyticsReportInstances.id(instance.id).segments.get(
                limit: 10
            )
        )

        guard let segment = segmentsResponse.data.first,
            let downloadURL = segment.attributes?.url
        else {
            return .init(
                content: [.text("Error: No downloadable segments found for this report instance.")],
                isError: true)
        }

        // Step 6: Download CSV data from pre-signed URL
        let (data, _) = try await URLSession.shared.data(from: downloadURL)

        // The data is typically gzip-compressed; check for gzip magic bytes
        let csvText: String
        if data.count >= 2 && data[0] == 0x1f && data[1] == 0x8b {
            // Gzip compressed — write to temp file and decompress with system gzip
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".gz")
            try data.write(to: tempURL)
            let decompressed = try decompressGzip(fileURL: tempURL)
            try? FileManager.default.removeItem(at: tempURL)
            guard let text = String(data: decompressed, encoding: .utf8) else {
                return .init(
                    content: [.text("Error: Could not decode decompressed report data as text.")],
                    isError: true)
            }
            csvText = text
        } else if let text = String(data: data, encoding: .utf8) {
            csvText = text
        } else {
            return .init(
                content: [.text("Error: Could not decode downloaded report data as text.")],
                isError: true)
        }

        // Step 7: Parse CSV/TSV
        let parsed = CSVParser.parse(csvText)

        // Limit to first 100 rows to avoid huge responses
        let maxRows = 100
        let limitedRows = Array(parsed.rows.prefix(maxRows))

        let result: [String: Any] = [
            "appId": appId,
            "reportName": reportName,
            "category": categoryStr,
            "granularity": granularityStr,
            "processingDate": instance.attributes?.processingDate ?? "",
            "headers": parsed.headers,
            "rows": limitedRows,
            "totalRows": parsed.rows.count,
            "rowsReturned": limitedRows.count,
            "truncated": parsed.rows.count > maxRows,
        ]

        let json = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        let text = String(data: json, encoding: .utf8) ?? "{}"
        return .init(content: [.text(text)])
    }

    /// Decompress gzip file using system gzip binary
    private static func decompressGzip(fileURL: URL) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/gzip")
        process.arguments = ["-d", "-c", fileURL.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return data
    }
}
