import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum GetDiagnosticsTool {
    static let tool = Tool(
        name: "get_diagnostics",
        description:
            "Get diagnostic signatures (top issues like hangs, disk writes, slow launches) for a build. If no buildId is provided, automatically uses the latest valid build.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "appId": .object(["type": "string", "description": "App Store app ID"]),
                "diagnosticType": .object([
                    "type": "string",
                    "description": "Filter by diagnostic type. Omit for all types.",
                    "enum": .array([
                        .string("DISK_WRITES"), .string("HANGS"), .string("LAUNCHES"),
                    ]),
                ]),
                "buildId": .object([
                    "type": "string",
                    "description":
                        "Build ID to get diagnostics for. If omitted, uses the latest valid build.",
                ]),
                "limit": .object([
                    "type": "number",
                    "description": "Maximum number of diagnostic signatures to return (default: 10)",
                    "default": .int(10),
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

        let diagnosticTypeStr = arguments?["diagnosticType"]?.stringValue
        let providedBuildId = arguments?["buildId"]?.stringValue
        let limit = arguments?["limit"]?.intValue ?? 10

        // Resolve build ID
        let buildId: String
        var buildVersion: String? = nil
        var buildUploadedDate: String? = nil

        if let providedBuildId {
            buildId = providedBuildId
        } else {
            // Auto-resolve latest valid build
            let buildsResponse = try await client.send(
                Resources.v1.builds.get(
                    filterProcessingState: [.valid],
                    filterApp: [appId],
                    sort: [.minusUploadedDate],
                    limit: 1
                )
            )
            guard let latestBuild = buildsResponse.data.first else {
                return .init(
                    content: [.text("Error: No valid builds found for app \(appId)")],
                    isError: true)
            }
            buildId = latestBuild.id
            buildVersion = latestBuild.attributes?.version
            if let date = latestBuild.attributes?.uploadedDate {
                let formatter = ISO8601DateFormatter()
                buildUploadedDate = formatter.string(from: date)
            }
        }

        // Map optional diagnosticType to filter enum
        typealias FilterDiagnosticType =
            Resources.V1.Builds.WithID.DiagnosticSignatures.FilterDiagnosticType
        var diagFilter: [FilterDiagnosticType]? = nil
        if let diagnosticTypeStr {
            switch diagnosticTypeStr {
            case "DISK_WRITES": diagFilter = [.diskWrites]
            case "HANGS": diagFilter = [.hangs]
            case "LAUNCHES": diagFilter = [.launches]
            default:
                return .init(
                    content: [
                        .text(
                            "Error: Invalid diagnosticType '\(diagnosticTypeStr)'. Must be one of: DISK_WRITES, HANGS, LAUNCHES"
                        )
                    ], isError: true)
            }
        }

        let response = try await client.send(
            Resources.v1.builds.id(buildId).diagnosticSignatures.get(
                filterDiagnosticType: diagFilter,
                limit: limit
            )
        )

        // Build diagnostics array
        var diagnostics: [[String: Any]] = []
        for signature in response.data {
            let attrs = signature.attributes
            var entry: [String: Any] = [
                "signatureId": signature.id,
                "diagnosticType": attrs?.diagnosticType?.rawValue ?? "unknown",
                "signature": attrs?.signature ?? "",
                "weight": attrs?.weight as Any,
            ]
            if let insight = attrs?.insight {
                var insightDict: [String: Any] = [
                    "direction": insight.direction?.rawValue ?? "unknown"
                ]
                if let refs = insight.referenceVersions {
                    insightDict["referenceVersions"] = refs.map { ref in
                        [
                            "version": ref.version ?? "",
                            "value": ref.value as Any,
                        ] as [String: Any]
                    }
                }
                entry["insight"] = insightDict
            }
            diagnostics.append(entry)
        }

        var result: [String: Any] = [
            "appId": appId,
            "buildId": buildId,
            "diagnosticCount": diagnostics.count,
            "diagnostics": diagnostics,
        ]
        if let buildVersion {
            result["buildVersion"] = buildVersion
        }
        if let buildUploadedDate {
            result["buildUploadedDate"] = buildUploadedDate
        }

        let json = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        let text = String(data: json, encoding: .utf8) ?? "{}"
        return .init(content: [.text(text)])
    }
}
