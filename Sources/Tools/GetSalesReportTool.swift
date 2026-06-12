import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum GetSalesReportTool {
    static let tool = Tool(
        name: "get_sales_report",
        description:
            "Download sales & trends report data from App Store Connect. Covers units sold, proceeds, updates, refunds, and more. Returns parsed TSV data as JSON. NOTE: SUBSCRIPTION, SUBSCRIPTION_EVENT, and SUBSCRIBER report types are being deprecated by Apple mid-2026. Use get_analytics_report with COMMERCE category instead.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "vendorNumber": .object([
                    "type": "string",
                    "description":
                        "Vendor number from App Store Connect (found in Payments & Financial Reports). Optional if vendorNumber is set in ~/.asc-metadata-mcp/config.json.",
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
                "aggregateBy": .object([
                    "type": "string",
                    "description":
                        "APP returns per-app aggregates (downloads, redownloads, updates, IAP units, proceeds by currency) computed over ALL rows instead of raw rows — never truncated. NONE (default) returns raw rows.",
                    "enum": .array([.string("NONE"), .string("APP")]),
                    "default": "NONE",
                ]),
                "offset": .object([
                    "type": "integer",
                    "description": "Row offset for paginating raw rows (default: 0). Ignored when aggregateBy is APP.",
                    "default": 0,
                ]),
                "limit": .object([
                    "type": "integer",
                    "description": "Maximum raw rows to return, 1-1000 (default: 200). Ignored when aggregateBy is APP.",
                    "default": 200,
                ]),
            ]),
        ])
    )

    static func handle(
        arguments: [String: Value]?,
        client: AppStoreConnectClient
    ) async throws -> CallTool.Result {
        guard let vendorNumber = arguments?["vendorNumber"]?.stringValue ?? config.vendorNumber
        else {
            return .init(
                content: [
                    .text(
                        "Error: vendorNumber is required (pass it as an argument or set \"vendorNumber\" in ~/.asc-metadata-mcp/config.json)"
                    )
                ], isError: true)
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

        // Check for deprecated report types
        let deprecatedTypes: Set<String> = [
            "SUBSCRIPTION", "SUBSCRIPTION_EVENT", "SUBSCRIBER",
        ]
        let deprecationWarning: String? =
            deprecatedTypes.contains(reportTypeStr)
            ? "WARNING: '\(reportTypeStr)' reports are being deprecated by Apple mid-2026. Use 'get_analytics_report' with category 'COMMERCE' for subscription analytics instead."
            : nil

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
            let message = ResponseErrorFormatter.format(error)
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

        var result: [String: Any] = [
            "vendorNumber": vendorNumber,
            "reportType": reportTypeStr,
            "reportSubType": reportSubTypeStr,
            "frequency": frequencyStr,
            "reportDate": dateToUse,
            "totalRows": parsed.rows.count,
        ]

        let aggregateBy = arguments?["aggregateBy"]?.stringValue ?? "NONE"
        if aggregateBy == "APP" {
            switch aggregateByApp(parsed) {
            case .success(let appList, let totals):
                result["aggregateBy"] = "APP"
                result["apps"] = appList
                result["totals"] = totals
            case .missingColumns(let missing):
                return .init(
                    content: [
                        .text(
                            "Error: aggregateBy=APP needs columns missing from this report: \(missing.joined(separator: ", ")). It supports SALES-style reports (SALES/INSTALLS with SUMMARY or DETAILED sub-type)."
                        )
                    ], isError: true)
            }
        } else {
            // Paginate raw rows to avoid huge responses
            let offset = max(arguments?["offset"]?.intValue ?? 0, 0)
            let limit = min(max(arguments?["limit"]?.intValue ?? 200, 1), 1000)
            let end = min(offset + limit, parsed.rows.count)
            let pageRows = offset < end ? Array(parsed.rows[offset..<end]) : []

            result["headers"] = parsed.headers
            result["rows"] = pageRows
            result["offset"] = offset
            result["rowsReturned"] = pageRows.count
            result["truncated"] = offset > 0 || end < parsed.rows.count
            if end < parsed.rows.count {
                result["nextOffset"] = end
            }
        }

        if let warning = deprecationWarning {
            result["deprecationWarning"] = warning
        }

        let json = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        let text = String(data: json, encoding: .utf8) ?? "{}"
        return .init(content: [.text(text)])
    }

    // MARK: - Per-app aggregation

    private struct AppAggregate {
        var titles: Set<String> = []
        var skus: Set<String> = []
        var downloads = 0
        var redownloads = 0
        var updates = 0
        var iapUnits = 0
        var otherUnits: [String: Int] = [:]
        var proceeds: [String: Double] = [:]
    }

    private enum AggregationOutcome {
        case success(apps: [[String: Any]], totals: [String: Any])
        case missingColumns([String])
    }

    private static func aggregateByApp(_ parsed: CSVParser.ParsedData) -> AggregationOutcome {
        let needed = [
            "Apple Identifier", "Parent Identifier", "SKU", "Title",
            "Product Type Identifier", "Units", "Developer Proceeds",
            "Currency of Proceeds",
        ]
        var col: [String: Int] = [:]
        for (index, header) in parsed.headers.enumerated() {
            col[header] = index
        }
        let missing = needed.filter { col[$0] == nil }
        guard missing.isEmpty else { return .missingColumns(missing) }

        func field(_ row: [String], _ name: String) -> String {
            let index = col[name]!
            return index < row.count ? row[index].trimmingCharacters(in: .whitespaces) : ""
        }

        // First-time downloads, redownloads, and updates per Apple's
        // product type identifiers; IA*/FI1 are in-app purchases.
        let downloadTypes: Set<String> = ["1", "1F", "1T", "F1", "1E", "1EP", "1EU"]
        let redownloadTypes: Set<String> = ["3", "3F", "F3"]
        let updateTypes: Set<String> = ["7", "7F", "F7"]

        // IAP rows carry the parent app's SKU, not its Apple Identifier —
        // map SKUs to app identifiers so IAPs group under their app.
        var skuToAppleID: [String: String] = [:]
        for row in parsed.rows where field(row, "Parent Identifier").isEmpty {
            skuToAppleID[field(row, "SKU")] = field(row, "Apple Identifier")
        }

        var apps: [String: AppAggregate] = [:]
        var totals = AppAggregate()
        for row in parsed.rows {
            let parent = field(row, "Parent Identifier")
            let key = parent.isEmpty
                ? field(row, "Apple Identifier")
                : skuToAppleID[parent] ?? parent
            var app = apps[key] ?? AppAggregate()
            app.titles.insert(field(row, "Title"))
            app.skus.insert(parent.isEmpty ? field(row, "SKU") : parent)

            let productType = field(row, "Product Type Identifier")
            let units = Int(field(row, "Units")) ?? 0
            if downloadTypes.contains(productType) {
                app.downloads += units
                totals.downloads += units
            } else if redownloadTypes.contains(productType) {
                app.redownloads += units
                totals.redownloads += units
            } else if updateTypes.contains(productType) {
                app.updates += units
                totals.updates += units
            } else if productType.hasPrefix("IA") || productType == "FI1" {
                app.iapUnits += units
                totals.iapUnits += units
            } else {
                app.otherUnits[productType, default: 0] += units
                totals.otherUnits[productType, default: 0] += units
            }

            let proceedsPerUnit = Double(field(row, "Developer Proceeds")) ?? 0
            if proceedsPerUnit != 0 {
                let currency = field(row, "Currency of Proceeds")
                let amount = proceedsPerUnit * Double(units)
                app.proceeds[currency, default: 0] += amount
                totals.proceeds[currency, default: 0] += amount
            }
            apps[key] = app
        }

        func encode(_ aggregate: AppAggregate, identifier: String?) -> [String: Any] {
            var entry: [String: Any] = [
                "downloads": aggregate.downloads,
                "redownloads": aggregate.redownloads,
                "updates": aggregate.updates,
                "iapUnits": aggregate.iapUnits,
                "proceeds": aggregate.proceeds.mapValues { ($0 * 100).rounded() / 100 },
            ]
            if !aggregate.otherUnits.isEmpty {
                entry["otherUnits"] = aggregate.otherUnits
            }
            if let identifier {
                entry["appleIdentifier"] = identifier
                entry["titles"] = aggregate.titles.sorted()
                entry["skus"] = aggregate.skus.sorted()
            }
            return entry
        }

        let appList = apps
            .sorted { ($0.value.downloads, $1.key) > ($1.value.downloads, $0.key) }
            .map { encode($0.value, identifier: $0.key) }
        return .success(apps: appList, totals: encode(totals, identifier: nil))
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

}
