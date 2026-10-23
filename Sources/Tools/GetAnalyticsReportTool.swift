import AppStoreAPI
import AppStoreConnect
import Foundation
import MCP

enum GetAnalyticsReportTool {
    static let tool = Tool(
        name: "get_analytics_report",
        description:
            "Download analytics report data for an app. Requires setup_analytics_reports to be run first. If no reportName is specified, lists available reports for discovery. Categories: APP_USAGE, APP_STORE_ENGAGEMENT, COMMERCE, FRAMEWORK_USAGE, PERFORMANCE. Raw rows are paged with offset/limit. Pass groupBy to get numeric columns summed over ALL rows of the instance instead (never truncated). With no date, the newest instance is used; availableProcessingDates lists what else exists.",
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
                        "Processing date in YYYY-MM-DD format. If omitted, the newest available instance is used. Weekly instances are typically processed on a Friday and cover the week ending the previous Sunday; daily instances can carry two or three days of late-arriving rows.",
                ]),
                "offset": .object([
                    "type": "integer",
                    "description":
                        "Row offset for paging raw rows (default: 0). Ignored when groupBy is set.",
                    "default": 0,
                ]),
                "limit": .object([
                    "type": "integer",
                    "description":
                        "Maximum raw rows to return, 1-1000 (default: 200). Ignored when groupBy is set.",
                    "default": 200,
                ]),
                "groupBy": .object([
                    "type": "array",
                    "items": .object(["type": "string"]),
                    "description":
                        "Column names to group by, e.g. [\"Date\",\"Event\",\"Page Type\",\"Source Type\"]. Returns one row per distinct combination with numeric columns summed over ALL rows of the instance — never truncated. Names must match the report headers exactly.",
                ]),
                "sum": .object([
                    "type": "array",
                    "items": .object(["type": "string"]),
                    "description":
                        "With groupBy: the columns to sum. Default: every column not in groupBy whose values are all numeric, skipping ID columns. A 'Unique' column summed across dimensions overcounts and is flagged in the response.",
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
        let offset = max(arguments?["offset"]?.intValue ?? 0, 0)
        let limit = min(max(arguments?["limit"]?.intValue ?? 200, 1), 1000)
        let groupBy = stringList(arguments, "groupBy")
        let requestedSums = stringList(arguments, "sum")

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
                limit: 200
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

        // Step 4: Collect every instance for this granularity (all pages), newest first.
        // The API returns instances oldest-first, so "take the first" silently picks the
        // oldest; we sort by processingDate ourselves.
        var dated: [(date: String, instance: AnalyticsReportInstance)] = []
        for try await page in client.pages(
            Resources.v1.analyticsReports.id(report.id).instances.get(
                filterGranularity: [granularityFilter],
                limit: 200
            )
        ) {
            for instance in page.data {
                if let date = instance.attributes?.processingDate {
                    dated.append((date, instance))
                }
            }
        }
        dated.sort { $0.date > $1.date }
        let availableDates = dated.map(\.date)

        guard !dated.isEmpty else {
            return .init(
                content: [
                    .text(
                        "No report instances found for granularity '\(granularityStr)'. Try a different granularity, or wait: instances appear 24-48 hours after setup."
                    )
                ], isError: true)
        }

        let chosen: (date: String, instance: AnalyticsReportInstance)
        if let dateStr {
            guard let match = dated.first(where: { $0.date == dateStr }) else {
                let sample = availableDates.prefix(15).joined(separator: ", ")
                return .init(
                    content: [
                        .text(
                            "No instance with processingDate '\(dateStr)' for granularity '\(granularityStr)'. Available processing dates (newest first): \(sample)\(availableDates.count > 15 ? ", …" : "")"
                        )
                    ], isError: true)
            }
            chosen = match
        } else {
            chosen = dated[0]
        }

        // Step 5: Collect every segment (large instances are split into several files)
        var segmentURLs: [URL] = []
        for try await page in client.pages(
            Resources.v1.analyticsReportInstances.id(chosen.instance.id).segments.get(limit: 200)
        ) {
            segmentURLs.append(contentsOf: page.data.compactMap { $0.attributes?.url })
        }

        guard !segmentURLs.isEmpty else {
            return .init(
                content: [.text("Error: No downloadable segments found for this report instance.")],
                isError: true)
        }

        // Step 6 and 7: Download, decompress and parse each segment; concatenate rows
        var headers: [String] = []
        var rows: [[String]] = []
        var headerMismatch = false
        for (index, url) in segmentURLs.enumerated() {
            guard let text = try await downloadText(from: url) else {
                return .init(
                    content: [.text("Error: Could not decode report segment \(index + 1) of \(segmentURLs.count) as text.")],
                    isError: true)
            }
            let parsed = CSVParser.parse(text)
            if index == 0 {
                headers = parsed.headers
            } else if parsed.headers != headers {
                headerMismatch = true
            }
            rows.append(contentsOf: parsed.rows)
        }

        var result: [String: Any] = [
            "appId": appId,
            "reportName": reportName,
            "category": categoryStr,
            "granularity": granularityStr,
            "processingDate": chosen.date,
            "instanceCount": dated.count,
            "availableProcessingDates": Array(availableDates.prefix(30)),
            "segmentCount": segmentURLs.count,
            "headers": headers,
            "totalRows": rows.count,
        ]
        if headerMismatch {
            result["warning"] =
                "Segment headers differ; rows were concatenated using the first segment's headers."
        }

        if groupBy.isEmpty {
            let end = min(offset + limit, rows.count)
            let pageRows = offset < end ? Array(rows[offset..<end]) : []
            result["rows"] = pageRows
            result["offset"] = offset
            result["limit"] = limit
            result["rowsReturned"] = pageRows.count
            result["truncated"] = offset > 0 || end < rows.count
            if end < rows.count {
                result["nextOffset"] = end
            }
        } else {
            switch aggregate(headers: headers, rows: rows, groupBy: groupBy, sum: requestedSums) {
            case .failure(let message):
                return .init(content: [.text("Error: \(message)")], isError: true)
            case .success(let agg):
                result["groupBy"] = groupBy
                result["sum"] = agg.sumColumns
                result["headers"] = groupBy + agg.sumColumns
                result["rows"] = agg.rows
                result["rowsReturned"] = agg.rows.count
                result["truncated"] = false
                if agg.sumColumns.contains(where: { $0.localizedCaseInsensitiveContains("unique") }) {
                    result["note"] =
                        "A 'Unique' column summed across dimensions overcounts unique users; treat it as an upper bound."
                }
            }
        }

        let json = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        let text = String(data: json, encoding: .utf8) ?? "{}"
        return .init(content: [.text(text)])
    }

    // MARK: - Helpers

    private static func stringList(_ arguments: [String: Value]?, _ key: String) -> [String] {
        if case .array(let items)? = arguments?[key] {
            return items.compactMap { $0.stringValue }
        }
        return []
    }

    private struct Aggregate {
        let sumColumns: [String]
        let rows: [[Any]]
    }

    private enum AggregateResult {
        case success(Aggregate)
        case failure(String)
    }

    /// Group rows by the given columns and sum the numeric columns. Output rows are
    /// sorted by their group key so results are stable across calls.
    private static func aggregate(
        headers: [String], rows: [[String]], groupBy: [String], sum requested: [String]
    ) -> AggregateResult {
        var index: [String: Int] = [:]
        for (i, h) in headers.enumerated() where index[h] == nil {
            index[h] = i
        }
        let missing = (groupBy + requested).filter { index[$0] == nil }
        if !missing.isEmpty {
            return .failure(
                "Unknown column(s) \(missing.joined(separator: ", ")). Report headers: \(headers.joined(separator: ", "))"
            )
        }

        func value(_ row: [String], _ column: String) -> String {
            let i = index[column]!
            return i < row.count ? row[i] : ""
        }

        var sumColumns = requested
        if sumColumns.isEmpty {
            sumColumns = headers.filter { h in
                !groupBy.contains(h)
                    && !isIdentifierColumn(h)
                    && rows.contains { !value($0, h).isEmpty }
                    && rows.allSatisfy { r in
                        let v = value(r, h)
                        return v.isEmpty || Double(v) != nil
                    }
            }
            if sumColumns.isEmpty {
                return .failure(
                    "No numeric columns to sum; pass sum explicitly. Report headers: \(headers.joined(separator: ", "))"
                )
            }
        }

        var totals: [[String]: [Double]] = [:]
        for row in rows {
            let key = groupBy.map { value(row, $0) }
            var acc = totals[key] ?? Array(repeating: 0, count: sumColumns.count)
            for (j, column) in sumColumns.enumerated() {
                if let v = Double(value(row, column)) {
                    acc[j] += v
                }
            }
            totals[key] = acc
        }

        let keys = totals.keys.sorted { $0.lexicographicallyPrecedes($1) }
        let outRows: [[Any]] = keys.map { key in
            let sums: [Any] = totals[key]!.map { v in
                v == v.rounded() && abs(v) < 1e15 ? Int(v) as Any : v as Any
            }
            return key.map { $0 as Any } + sums
        }
        return .success(Aggregate(sumColumns: sumColumns, rows: outRows))
    }

    /// Numeric-looking ID columns (e.g. "App Apple Identifier") must never be summed.
    private static func isIdentifierColumn(_ header: String) -> Bool {
        let h = header.lowercased()
        return h.contains("identifier") || h == "id" || h.hasSuffix(" id") || h.hasSuffix("_id")
    }

    /// Download a segment and return its text, decompressing gzip when needed.
    private static func downloadText(from url: URL) async throws -> String? {
        let (data, _) = try await URLSession.shared.data(from: url)
        if data.count >= 2 && data[0] == 0x1f && data[1] == 0x8b {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".gz")
            try data.write(to: tempURL)
            defer { try? FileManager.default.removeItem(at: tempURL) }
            let decompressed = try decompressGzip(fileURL: tempURL)
            return String(data: decompressed, encoding: .utf8)
        }
        return String(data: data, encoding: .utf8)
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
