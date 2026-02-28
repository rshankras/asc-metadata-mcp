import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum GetFinanceReportTool {
    static let tool = Tool(
        name: "get_finance_report",
        description:
            "Download monthly financial settlement report from App Store Connect. Shows payments and proceeds by region. Reports are available after Apple processes the monthly payment cycle.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "vendorNumber": .object([
                    "type": "string",
                    "description":
                        "Vendor number from App Store Connect (found in Payments & Financial Reports)",
                ]),
                "reportDate": .object([
                    "type": "string",
                    "description": "Month in YYYY-MM format (e.g. 2025-01)",
                ]),
                "regionCode": .object([
                    "type": "string",
                    "description":
                        "Region code (e.g. US, EU, JP, AU, CA, MX, GB, CN, etc.)",
                ]),
                "reportType": .object([
                    "type": "string",
                    "description": "Report type (default: FINANCIAL)",
                    "enum": .array([
                        .string("FINANCIAL"), .string("FINANCE_DETAIL"),
                    ]),
                    "default": "FINANCIAL",
                ]),
            ]),
            "required": .array([
                .string("vendorNumber"), .string("reportDate"), .string("regionCode"),
            ]),
        ])
    )

    static func handle(
        arguments: [String: Value]?,
        client: AppStoreConnectClient
    ) async throws -> CallTool.Result {
        guard let vendorNumber = arguments?["vendorNumber"]?.stringValue else {
            return .init(content: [.text("Error: vendorNumber is required")], isError: true)
        }
        guard let reportDate = arguments?["reportDate"]?.stringValue else {
            return .init(content: [.text("Error: reportDate is required (YYYY-MM format)")], isError: true)
        }
        guard let regionCode = arguments?["regionCode"]?.stringValue else {
            return .init(content: [.text("Error: regionCode is required (e.g. US, EU, JP)")], isError: true)
        }

        let reportTypeStr = arguments?["reportType"]?.stringValue ?? "FINANCIAL"

        // Map reportType string to SDK enum
        typealias FilterReportType = Resources.V1.FinanceReports.FilterReportType
        let reportType: FilterReportType
        switch reportTypeStr {
        case "FINANCIAL": reportType = .financial
        case "FINANCE_DETAIL": reportType = .financeDetail
        default:
            return .init(
                content: [
                    .text(
                        "Error: Invalid reportType '\(reportTypeStr)'. Must be one of: FINANCIAL, FINANCE_DETAIL"
                    )
                ], isError: true)
        }

        // Download the report via SDK
        let fileURL: URL
        do {
            fileURL = try await client.download(
                Resources.v1.financeReports.get(
                    filterVendorNumber: [vendorNumber],
                    filterReportType: [reportType],
                    filterRegionCode: [regionCode],
                    filterReportDate: [reportDate]
                )
            )
        } catch let error as ResponseError {
            let message = formatResponseError(error)
            return .init(content: [.text("Error downloading finance report: \(message)")], isError: true)
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
            "regionCode": regionCode,
            "reportDate": reportDate,
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
