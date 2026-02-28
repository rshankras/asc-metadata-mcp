import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum GetSalesReportTool {
    static let tool = Tool(
        name: "get_sales_report",
        description:
            "Download sales & trends report data from App Store Connect. Covers units sold, proceeds, updates, refunds, and more. Returns parsed TSV data as JSON.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "vendorNumber": .object([
                    "type": "string",
                    "description":
                        "Vendor number from App Store Connect (found in Payments & Financial Reports)",
                ]),
                "reportType": .object([
                    "type": "string",
                    "description": "Type of sales report (default: SALES)",
                    "enum": .array([
                        .string("SALES"), .string("PRE_ORDER"),
                        .string("SUBSCRIPTION"), .string("SUBSCRIPTION_EVENT"),
                        .string("SUBSCRIBER"), .string("INSTALLS"),
                    ]),
                    "default": "SALES",
                ]),
                "reportSubType": .object([
                    "type": "string",
                    "description": "Report sub-type (default: SUMMARY)",
                    "enum": .array([
                        .string("SUMMARY"), .string("DETAILED"),
                        .string("SUMMARY_INSTALL_TYPE"), .string("SUMMARY_TERRITORY"),
                        .string("SUMMARY_CHANNEL"),
                    ]),
                    "default": "SUMMARY",
                ]),
                "frequency": .object([
                    "type": "string",
                    "description": "Report frequency (default: DAILY)",
                    "enum": .array([
                        .string("DAILY"), .string("WEEKLY"),
                        .string("MONTHLY"), .string("YEARLY"),
                    ]),
                    "default": "DAILY",
                ]),
                "reportDate": .object([
                    "type": "string",
                    "description":
                        "Date in YYYY-MM-DD format. If omitted, defaults to yesterday.",
                ]),
            ]),
            "required": .array([.string("vendorNumber")]),
        ])
    )

    static func handle(
        arguments: [String: Value]?,
        client: AppStoreConnectClient
    ) async throws -> CallTool.Result {
        guard let vendorNumber = arguments?["vendorNumber"]?.stringValue else {
            return .init(content: [.text("Error: vendorNumber is required")], isError: true)
        }

        let reportTypeStr = arguments?["reportType"]?.stringValue ?? "SALES"
        let reportSubTypeStr = arguments?["reportSubType"]?.stringValue ?? "SUMMARY"
        let frequencyStr = arguments?["frequency"]?.stringValue ?? "DAILY"
        let reportDate = arguments?["reportDate"]?.stringValue

        // Map reportType string to SDK enum
        typealias FilterReportType = Resources.V1.SalesReports.FilterReportType
        let reportType: FilterReportType
        switch reportTypeStr {
        case "SALES": reportType = .sales
        case "PRE_ORDER": reportType = .preOrder
        case "SUBSCRIPTION": reportType = .subscription
        case "SUBSCRIPTION_EVENT": reportType = .subscriptionEvent
        case "SUBSCRIBER": reportType = .subscriber
        case "INSTALLS": reportType = .installs
        default:
            return .init(
                content: [
                    .text(
                        "Error: Invalid reportType '\(reportTypeStr)'. Must be one of: SALES, PRE_ORDER, SUBSCRIPTION, SUBSCRIPTION_EVENT, SUBSCRIBER, INSTALLS"
                    )
                ], isError: true)
        }

        // Map reportSubType string to SDK enum
        typealias FilterReportSubType = Resources.V1.SalesReports.FilterReportSubType
        let reportSubType: FilterReportSubType
        switch reportSubTypeStr {
        case "SUMMARY": reportSubType = .summary
        case "DETAILED": reportSubType = .detailed
        case "SUMMARY_INSTALL_TYPE": reportSubType = .summaryInstallType
        case "SUMMARY_TERRITORY": reportSubType = .summaryTerritory
        case "SUMMARY_CHANNEL": reportSubType = .summaryChannel
        default:
            return .init(
                content: [
                    .text(
                        "Error: Invalid reportSubType '\(reportSubTypeStr)'. Must be one of: SUMMARY, DETAILED, SUMMARY_INSTALL_TYPE, SUMMARY_TERRITORY, SUMMARY_CHANNEL"
                    )
                ], isError: true)
        }

        // Map frequency string to SDK enum
        typealias FilterFrequency = Resources.V1.SalesReports.FilterFrequency
        let frequency: FilterFrequency
        switch frequencyStr {
        case "DAILY": frequency = .daily
        case "WEEKLY": frequency = .weekly
        case "MONTHLY": frequency = .monthly
        case "YEARLY": frequency = .yearly
        default:
            return .init(
                content: [
                    .text(
                        "Error: Invalid frequency '\(frequencyStr)'. Must be one of: DAILY, WEEKLY, MONTHLY, YEARLY"
                    )
                ], isError: true)
        }

        // Default reportDate to yesterday if not provided
        let dateToUse: String
        if let reportDate {
            dateToUse = reportDate
        } else {
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            dateToUse = formatter.string(from: yesterday)
        }

        // Download the report via SDK
        let fileURL: URL
        do {
            fileURL = try await client.download(
                Resources.v1.salesReports.get(
                    filterVendorNumber: [vendorNumber],
                    filterReportType: [reportType],
                    filterReportSubType: [reportSubType],
                    filterFrequency: [frequency],
                    filterReportDate: [dateToUse]
                )
            )
        } catch let error as ResponseError {
            let message = formatResponseError(error)
            return .init(content: [.text("Error downloading sales report: \(message)")], isError: true)
        }

        // Read and decompress file contents
        let tsvText: String
        let fileData = try Data(contentsOf: fileURL)

        // Check for gzip magic bytes (0x1f, 0x8b)
        if fileData.count >= 2 && fileData[0] == 0x1f && fileData[1] == 0x8b {
            // Decompress gzip using system gunzip
            let decompressed = try decompressGzip(fileURL: fileURL)
            guard let text = String(data: decompressed, encoding: .utf8) else {
                return .init(
                    content: [.text("Error: Could not decode decompressed report data as text.")],
                    isError: true)
            }
            tsvText = text
        } else if let text = String(data: fileData, encoding: .utf8) {
            tsvText = text
        } else {
            return .init(
                content: [.text("Error: Could not decode downloaded report data as text.")],
                isError: true)
        }

        // Clean up temp file
        try? FileManager.default.removeItem(at: fileURL)

        // Parse TSV
        let parsed = CSVParser.parse(tsvText)

        // Limit rows to avoid huge responses
        let maxRows = 200
        let limitedRows = Array(parsed.rows.prefix(maxRows))

        let result: [String: Any] = [
            "vendorNumber": vendorNumber,
            "reportType": reportTypeStr,
            "reportSubType": reportSubTypeStr,
            "frequency": frequencyStr,
            "reportDate": dateToUse,
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

    private static func formatResponseError(_ error: ResponseError) -> String {
        switch error {
        case .requestFailure(let errorResponse, let statusCode, _):
            var message = "HTTP \(statusCode)"
            if let errors = errorResponse?.errors {
                let details = errors.map { "\($0.code): \($0.detail)" }.joined(separator: "; ")
                message += " - \(details)"
            }
            return message
        case .rateLimitExceeded(_, let rate, _):
            return "Rate limit exceeded. Limit: \(rate?.limit ?? 0), remaining: \(rate?.remaining ?? 0)"
        case .dataAssertionFailed:
            return "No data returned from API"
        }
    }
}
