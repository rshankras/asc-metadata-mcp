import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum GetPerfMetricsTool {
    static let tool = Tool(
        name: "get_perf_metrics",
        description:
            "Get performance and power metrics for an iOS app. Returns Xcode-style metrics with regression/improvement insights. Only available for iOS apps.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "appId": .object(["type": "string", "description": "App Store app ID"]),
                "metricType": .object([
                    "type": "string",
                    "description":
                        "Filter by metric type. Omit for all metrics.",
                    "enum": .array([
                        .string("DISK"), .string("HANG"), .string("BATTERY"),
                        .string("LAUNCH"), .string("MEMORY"), .string("ANIMATION"),
                        .string("TERMINATION"),
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

        let metricTypeStr = arguments?["metricType"]?.stringValue

        // Map optional metricType string to filter enum
        typealias FilterMetricType = Resources.V1.Apps.WithID.PerfPowerMetrics.FilterMetricType
        var metricFilter: [FilterMetricType]? = nil
        if let metricTypeStr {
            switch metricTypeStr {
            case "DISK": metricFilter = [.disk]
            case "HANG": metricFilter = [.hang]
            case "BATTERY": metricFilter = [.battery]
            case "LAUNCH": metricFilter = [.launch]
            case "MEMORY": metricFilter = [.memory]
            case "ANIMATION": metricFilter = [.animation]
            case "TERMINATION": metricFilter = [.termination]
            default:
                return .init(
                    content: [
                        .text(
                            "Error: Invalid metricType '\(metricTypeStr)'. Must be one of: DISK, HANG, BATTERY, LAUNCH, MEMORY, ANIMATION, TERMINATION"
                        )
                    ], isError: true)
            }
        }

        let response = try await client.send(
            Resources.v1.apps.id(appId).perfPowerMetrics.get(
                filterPlatform: [.iOS],
                filterMetricType: metricFilter
            )
        )

        // Build insights section
        var insights: [[String: Any]] = []

        if let regressions = response.insights?.regressions {
            for insight in regressions {
                var entry: [String: Any] = [
                    "type": "regression",
                    "metricCategory": insight.metricCategory?.rawValue ?? "unknown",
                    "metric": insight.metric ?? "",
                    "summaryString": insight.summaryString ?? "",
                    "latestVersion": insight.latestVersion ?? "",
                    "isHighImpact": insight.isHighImpact ?? false,
                ]
                if let pops = insight.populations {
                    entry["populations"] = pops.map { pop in
                        [
                            "percentile": pop.percentile ?? "",
                            "device": pop.device ?? "",
                            "summaryString": pop.summaryString ?? "",
                            "deltaPercentage": pop.deltaPercentage as Any,
                            "latestVersionValue": pop.latestVersionValue as Any,
                            "referenceAverageValue": pop.referenceAverageValue as Any,
                        ] as [String: Any]
                    }
                }
                insights.append(entry)
            }
        }

        if let trendingUp = response.insights?.trendingUp {
            for insight in trendingUp {
                var entry: [String: Any] = [
                    "type": "improvement",
                    "metricCategory": insight.metricCategory?.rawValue ?? "unknown",
                    "metric": insight.metric ?? "",
                    "summaryString": insight.summaryString ?? "",
                    "latestVersion": insight.latestVersion ?? "",
                    "isHighImpact": insight.isHighImpact ?? false,
                ]
                if let pops = insight.populations {
                    entry["populations"] = pops.map { pop in
                        [
                            "percentile": pop.percentile ?? "",
                            "device": pop.device ?? "",
                            "summaryString": pop.summaryString ?? "",
                            "deltaPercentage": pop.deltaPercentage as Any,
                            "latestVersionValue": pop.latestVersionValue as Any,
                            "referenceAverageValue": pop.referenceAverageValue as Any,
                        ] as [String: Any]
                    }
                }
                insights.append(entry)
            }
        }

        // Build metrics section from productData
        var metrics: [[String: Any]] = []

        if let productData = response.productData {
            for product in productData {
                guard let categories = product.metricCategories else { continue }
                for category in categories {
                    for metric in category.metrics ?? [] {
                        var metricEntry: [String: Any] = [
                            "category": category.identifier?.rawValue ?? "unknown",
                            "metric": metric.identifier ?? "",
                            "unit": metric.unit?.displayName ?? "",
                        ]
                        var dataPoints: [[String: Any]] = []
                        for dataset in metric.datasets ?? [] {
                            let percentile = dataset.filterCriteria?.percentile ?? ""
                            let device = dataset.filterCriteria?.device ?? ""
                            for point in dataset.points ?? [] {
                                dataPoints.append([
                                    "version": point.version ?? "",
                                    "value": point.value as Any,
                                    "percentile": percentile,
                                    "device": device,
                                    "goal": point.goal ?? "",
                                ])
                            }
                        }
                        metricEntry["dataPoints"] = dataPoints
                        metrics.append(metricEntry)
                    }
                }
            }
        }

        let result: [String: Any] = [
            "appId": appId,
            "platform": "iOS",
            "insights": insights,
            "metrics": metrics,
        ]

        let json = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        let text = String(data: json, encoding: .utf8) ?? "{}"
        return .init(content: [.text(text)])
    }
}
