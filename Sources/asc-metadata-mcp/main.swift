import AppStoreConnect
import Foundation
import MCP

/// A tool's execution entry point. Every `XxxTool.handle` matches this shape,
/// which lets the registry below drive both `tools/list` and `tools/call`.
typealias ToolHandler = @Sendable ([String: Value]?, AppStoreConnectClient) async throws -> CallTool.Result

/// Single source of truth for the server's tools. Adding a tool is one line here —
/// `tools/list` and `tools/call` are both derived from it, so the two can never
/// drift out of sync (the old code kept a separate 67-entry list and 67-case switch).
let registry: [(tool: Tool, handle: ToolHandler)] = [
    (ListAppsTool.tool, ListAppsTool.handle),
    (GetMetadataTool.tool, GetMetadataTool.handle),
    (UpdateNameTool.tool, UpdateNameTool.handle),
    (UpdateKeywordsTool.tool, UpdateKeywordsTool.handle),
    (UpdateDescriptionTool.tool, UpdateDescriptionTool.handle),
    (UpdatePromoTextTool.tool, UpdatePromoTextTool.handle),
    (UpdateWhatsNewTool.tool, UpdateWhatsNewTool.handle),
    (ListLocalesTool.tool, ListLocalesTool.handle),
    (BulkUpdateTool.tool, BulkUpdateTool.handle),
    (CreateVersionTool.tool, CreateVersionTool.handle),
    (GetPerfMetricsTool.tool, GetPerfMetricsTool.handle),
    (GetDiagnosticsTool.tool, GetDiagnosticsTool.handle),
    (SetupAnalyticsReportsTool.tool, SetupAnalyticsReportsTool.handle),
    (GetAnalyticsReportTool.tool, GetAnalyticsReportTool.handle),
    (GetSalesReportTool.tool, GetSalesReportTool.handle),
    (GetFinanceReportTool.tool, GetFinanceReportTool.handle),
    (ListAppEventsTool.tool, ListAppEventsTool.handle),
    (CreateAppEventTool.tool, CreateAppEventTool.handle),
    (UpdateAppEventTool.tool, UpdateAppEventTool.handle),
    (DeleteAppEventTool.tool, DeleteAppEventTool.handle),
    (UpdateEventLocalizationTool.tool, UpdateEventLocalizationTool.handle),
    (ListIAPTool.tool, ListIAPTool.handle),
    (GetIAPTool.tool, GetIAPTool.handle),
    (CreateIAPTool.tool, CreateIAPTool.handle),
    (UpdateIAPTool.tool, UpdateIAPTool.handle),
    (DeleteIAPTool.tool, DeleteIAPTool.handle),
    (ListReviewsTool.tool, ListReviewsTool.handle),
    (GetReviewTool.tool, GetReviewTool.handle),
    (RespondToReviewTool.tool, RespondToReviewTool.handle),
    (DeleteReviewResponseTool.tool, DeleteReviewResponseTool.handle),
    (ListCustomPagesTool.tool, ListCustomPagesTool.handle),
    (CreateCustomPageTool.tool, CreateCustomPageTool.handle),
    (UpdateCustomPageTool.tool, UpdateCustomPageTool.handle),
    (DeleteCustomPageTool.tool, DeleteCustomPageTool.handle),
    (CreateCustomPageVersionTool.tool, CreateCustomPageVersionTool.handle),
    (ListExperimentsTool.tool, ListExperimentsTool.handle),
    (CreateExperimentTool.tool, CreateExperimentTool.handle),
    (UpdateExperimentTool.tool, UpdateExperimentTool.handle),
    (DeleteExperimentTool.tool, DeleteExperimentTool.handle),
    (CreateExperimentTreatmentTool.tool, CreateExperimentTreatmentTool.handle),
    (ListSubscriptionGroupsTool.tool, ListSubscriptionGroupsTool.handle),
    (CreateSubscriptionGroupTool.tool, CreateSubscriptionGroupTool.handle),
    (ListSubscriptionsTool.tool, ListSubscriptionsTool.handle),
    (CreateSubscriptionTool.tool, CreateSubscriptionTool.handle),
    (UpdateSubscriptionTool.tool, UpdateSubscriptionTool.handle),
    (GetAppPricingTool.tool, GetAppPricingTool.handle),
    (ListPricePointsTool.tool, ListPricePointsTool.handle),
    (GetAvailabilityTool.tool, GetAvailabilityTool.handle),
    (UpdateAvailabilityTool.tool, UpdateAvailabilityTool.handle),
    (CreatePhasedReleaseTool.tool, CreatePhasedReleaseTool.handle),
    (UpdatePhasedReleaseTool.tool, UpdatePhasedReleaseTool.handle),
    (DeletePhasedReleaseTool.tool, DeletePhasedReleaseTool.handle),
    (GetAgeRatingTool.tool, GetAgeRatingTool.handle),
    (UpdateAgeRatingTool.tool, UpdateAgeRatingTool.handle),
    (UpdateAccessibilityTool.tool, UpdateAccessibilityTool.handle),
    (ListBetaGroupsTool.tool, ListBetaGroupsTool.handle),
    (CreateBetaGroupTool.tool, CreateBetaGroupTool.handle),
    (UpdateBetaGroupTool.tool, UpdateBetaGroupTool.handle),
    (DeleteBetaGroupTool.tool, DeleteBetaGroupTool.handle),
    (AddBetaTesterTool.tool, AddBetaTesterTool.handle),
    (ListWebhooksTool.tool, ListWebhooksTool.handle),
    (CreateWebhookTool.tool, CreateWebhookTool.handle),
    (UpdateWebhookTool.tool, UpdateWebhookTool.handle),
    (DeleteWebhookTool.tool, DeleteWebhookTool.handle),
    (PingWebhookTool.tool, PingWebhookTool.handle),
    (ListBetaFeedbackCrashesTool.tool, ListBetaFeedbackCrashesTool.handle),
    (ListBetaFeedbackScreenshotsTool.tool, ListBetaFeedbackScreenshotsTool.handle),
]

let toolList = registry.map(\.tool)
let handlersByName = Dictionary(uniqueKeysWithValues: registry.map { ($0.tool.name, $0.handle) })

/// Milliseconds elapsed since `start`, for timing log lines.
func elapsedMs(since start: Date) -> Int { Int(Date().timeIntervalSince(start) * 1000) }

// Load auth config and create the ASC client. Surface failures on stderr — a bare
// throw here would otherwise exit with an opaque message the MCP host can't explain.
// `config` is intentionally global: the sales/finance report tools read
// `config.vendorNumber` as a default. `ascClient` drives every API call.
let config: AuthConfig
let ascClient: AppStoreConnectClient
do {
    config = try AuthConfig.load()
    ascClient = try config.createClient()
} catch {
    Log.error("startup failed: \(error.localizedDescription)")
    throw error
}

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
    .init(tools: toolList)
}

// Register tool execution
await server.withMethodHandler(CallTool.self) { params in
    let start = Date()
    guard let handle = handlersByName[params.name] else {
        Log.error("unknown tool: \(params.name)")
        return .init(content: [.text("Unknown tool: \(params.name)")], isError: true)
    }
    // Note: tool arguments are intentionally NOT logged — they can contain app
    // metadata, keywords, and other sensitive values.
    do {
        let result = try await handle(params.arguments, ascClient)
        Log.info("tool \(params.name) ok (\(elapsedMs(since: start))ms)")
        return result
    } catch let error as ResponseError {
        let message = ResponseErrorFormatter.format(error)
        Log.error("tool \(params.name) failed (\(elapsedMs(since: start))ms): \(message)")
        return .init(content: [.text("Error: \(message)")], isError: true)
    } catch {
        Log.error("tool \(params.name) failed (\(elapsedMs(since: start))ms): \(error.localizedDescription)")
        return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
    }
}

// Start with stdio transport and run until the client disconnects (stdin EOF).
Log.info("asc-metadata MCP server starting — \(toolList.count) tools, stdio transport")
let transport = StdioTransport()
try await server.start(transport: transport)
await server.waitUntilCompleted()
