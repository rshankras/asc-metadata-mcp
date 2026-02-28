import Foundation
import MCP

// Load auth config and create ASC client
let config = try AuthConfig.load()
let ascClient = try config.createClient()

// Create MCP server
let server = Server(
    name: "asc-metadata",
    version: "1.0.0",
    capabilities: Server.Capabilities(
        tools: .init(listChanged: false)
    )
)

// Register tool listing
await server.withMethodHandler(ListTools.self) { _ in
    .init(tools: [
        ListAppsTool.tool,
        GetMetadataTool.tool,
        UpdateNameTool.tool,
        UpdateKeywordsTool.tool,
        UpdateDescriptionTool.tool,
        UpdatePromoTextTool.tool,
        UpdateWhatsNewTool.tool,
        ListLocalesTool.tool,
        BulkUpdateTool.tool,
        CreateVersionTool.tool,
        GetPerfMetricsTool.tool,
        GetDiagnosticsTool.tool,
        SetupAnalyticsReportsTool.tool,
        GetAnalyticsReportTool.tool,
    ])
}

// Register tool execution
await server.withMethodHandler(CallTool.self) { params in
    do {
        switch params.name {
        case "list_apps":
            return try await ListAppsTool.handle(arguments: params.arguments, client: ascClient)
        case "get_metadata":
            return try await GetMetadataTool.handle(arguments: params.arguments, client: ascClient)
        case "update_name":
            return try await UpdateNameTool.handle(arguments: params.arguments, client: ascClient)
        case "update_keywords":
            return try await UpdateKeywordsTool.handle(
                arguments: params.arguments, client: ascClient)
        case "update_description":
            return try await UpdateDescriptionTool.handle(
                arguments: params.arguments, client: ascClient)
        case "update_promo_text":
            return try await UpdatePromoTextTool.handle(
                arguments: params.arguments, client: ascClient)
        case "update_whats_new":
            return try await UpdateWhatsNewTool.handle(
                arguments: params.arguments, client: ascClient)
        case "list_locales":
            return try await ListLocalesTool.handle(arguments: params.arguments, client: ascClient)
        case "bulk_update":
            return try await BulkUpdateTool.handle(arguments: params.arguments, client: ascClient)
        case "create_version":
            return try await CreateVersionTool.handle(
                arguments: params.arguments, client: ascClient)
        case "get_perf_metrics":
            return try await GetPerfMetricsTool.handle(
                arguments: params.arguments, client: ascClient)
        case "get_diagnostics":
            return try await GetDiagnosticsTool.handle(
                arguments: params.arguments, client: ascClient)
        case "setup_analytics_reports":
            return try await SetupAnalyticsReportsTool.handle(
                arguments: params.arguments, client: ascClient)
        case "get_analytics_report":
            return try await GetAnalyticsReportTool.handle(
                arguments: params.arguments, client: ascClient)
        default:
            return .init(content: [.text("Unknown tool: \(params.name)")], isError: true)
        }
    } catch {
        return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
    }
}

// Start with stdio transport
let transport = StdioTransport()
try await server.start(transport: transport)

// Keep server running
try await Task.sleep(for: .seconds(TimeInterval(Int.max)))
