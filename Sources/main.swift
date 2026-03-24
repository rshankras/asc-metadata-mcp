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
        GetSalesReportTool.tool,
        GetFinanceReportTool.tool,
        ListAppEventsTool.tool,
        CreateAppEventTool.tool,
        UpdateAppEventTool.tool,
        DeleteAppEventTool.tool,
        UpdateEventLocalizationTool.tool,
        ListIAPTool.tool,
        GetIAPTool.tool,
        CreateIAPTool.tool,
        UpdateIAPTool.tool,
        DeleteIAPTool.tool,
        ListReviewsTool.tool,
        GetReviewTool.tool,
        RespondToReviewTool.tool,
        DeleteReviewResponseTool.tool,
        ListCustomPagesTool.tool,
        CreateCustomPageTool.tool,
        UpdateCustomPageTool.tool,
        DeleteCustomPageTool.tool,
        CreateCustomPageVersionTool.tool,
        ListExperimentsTool.tool,
        CreateExperimentTool.tool,
        UpdateExperimentTool.tool,
        DeleteExperimentTool.tool,
        CreateExperimentTreatmentTool.tool,
        ListSubscriptionGroupsTool.tool,
        CreateSubscriptionGroupTool.tool,
        ListSubscriptionsTool.tool,
        CreateSubscriptionTool.tool,
        UpdateSubscriptionTool.tool,
        GetAppPricingTool.tool,
        ListPricePointsTool.tool,
        GetAvailabilityTool.tool,
        UpdateAvailabilityTool.tool,
        CreatePhasedReleaseTool.tool,
        UpdatePhasedReleaseTool.tool,
        DeletePhasedReleaseTool.tool,
        GetAgeRatingTool.tool,
        UpdateAgeRatingTool.tool,
        UpdateAccessibilityTool.tool,
        ListBetaGroupsTool.tool,
        CreateBetaGroupTool.tool,
        UpdateBetaGroupTool.tool,
        DeleteBetaGroupTool.tool,
        AddBetaTesterTool.tool,
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
        case "get_sales_report":
            return try await GetSalesReportTool.handle(
                arguments: params.arguments, client: ascClient)
        case "get_finance_report":
            return try await GetFinanceReportTool.handle(
                arguments: params.arguments, client: ascClient)
        case "list_app_events":
            return try await ListAppEventsTool.handle(
                arguments: params.arguments, client: ascClient)
        case "create_app_event":
            return try await CreateAppEventTool.handle(
                arguments: params.arguments, client: ascClient)
        case "update_app_event":
            return try await UpdateAppEventTool.handle(
                arguments: params.arguments, client: ascClient)
        case "delete_app_event":
            return try await DeleteAppEventTool.handle(
                arguments: params.arguments, client: ascClient)
        case "update_event_localization":
            return try await UpdateEventLocalizationTool.handle(
                arguments: params.arguments, client: ascClient)
        case "list_iap":
            return try await ListIAPTool.handle(
                arguments: params.arguments, client: ascClient)
        case "get_iap":
            return try await GetIAPTool.handle(
                arguments: params.arguments, client: ascClient)
        case "create_iap":
            return try await CreateIAPTool.handle(
                arguments: params.arguments, client: ascClient)
        case "update_iap":
            return try await UpdateIAPTool.handle(
                arguments: params.arguments, client: ascClient)
        case "delete_iap":
            return try await DeleteIAPTool.handle(
                arguments: params.arguments, client: ascClient)
        case "list_reviews":
            return try await ListReviewsTool.handle(
                arguments: params.arguments, client: ascClient)
        case "get_review":
            return try await GetReviewTool.handle(
                arguments: params.arguments, client: ascClient)
        case "respond_to_review":
            return try await RespondToReviewTool.handle(
                arguments: params.arguments, client: ascClient)
        case "delete_review_response":
            return try await DeleteReviewResponseTool.handle(
                arguments: params.arguments, client: ascClient)
        case "list_custom_pages":
            return try await ListCustomPagesTool.handle(
                arguments: params.arguments, client: ascClient)
        case "create_custom_page":
            return try await CreateCustomPageTool.handle(
                arguments: params.arguments, client: ascClient)
        case "update_custom_page":
            return try await UpdateCustomPageTool.handle(
                arguments: params.arguments, client: ascClient)
        case "delete_custom_page":
            return try await DeleteCustomPageTool.handle(
                arguments: params.arguments, client: ascClient)
        case "create_custom_page_version":
            return try await CreateCustomPageVersionTool.handle(
                arguments: params.arguments, client: ascClient)
        case "list_experiments":
            return try await ListExperimentsTool.handle(
                arguments: params.arguments, client: ascClient)
        case "create_experiment":
            return try await CreateExperimentTool.handle(
                arguments: params.arguments, client: ascClient)
        case "update_experiment":
            return try await UpdateExperimentTool.handle(
                arguments: params.arguments, client: ascClient)
        case "delete_experiment":
            return try await DeleteExperimentTool.handle(
                arguments: params.arguments, client: ascClient)
        case "create_experiment_treatment":
            return try await CreateExperimentTreatmentTool.handle(
                arguments: params.arguments, client: ascClient)
        case "list_subscription_groups":
            return try await ListSubscriptionGroupsTool.handle(
                arguments: params.arguments, client: ascClient)
        case "create_subscription_group":
            return try await CreateSubscriptionGroupTool.handle(
                arguments: params.arguments, client: ascClient)
        case "list_subscriptions":
            return try await ListSubscriptionsTool.handle(
                arguments: params.arguments, client: ascClient)
        case "create_subscription":
            return try await CreateSubscriptionTool.handle(
                arguments: params.arguments, client: ascClient)
        case "update_subscription":
            return try await UpdateSubscriptionTool.handle(
                arguments: params.arguments, client: ascClient)
        case "get_app_pricing":
            return try await GetAppPricingTool.handle(
                arguments: params.arguments, client: ascClient)
        case "list_price_points":
            return try await ListPricePointsTool.handle(
                arguments: params.arguments, client: ascClient)
        case "get_availability":
            return try await GetAvailabilityTool.handle(
                arguments: params.arguments, client: ascClient)
        case "update_availability":
            return try await UpdateAvailabilityTool.handle(
                arguments: params.arguments, client: ascClient)
        case "create_phased_release":
            return try await CreatePhasedReleaseTool.handle(
                arguments: params.arguments, client: ascClient)
        case "update_phased_release":
            return try await UpdatePhasedReleaseTool.handle(
                arguments: params.arguments, client: ascClient)
        case "delete_phased_release":
            return try await DeletePhasedReleaseTool.handle(
                arguments: params.arguments, client: ascClient)
        case "get_age_rating":
            return try await GetAgeRatingTool.handle(
                arguments: params.arguments, client: ascClient)
        case "update_age_rating":
            return try await UpdateAgeRatingTool.handle(
                arguments: params.arguments, client: ascClient)
        case "update_accessibility":
            return try await UpdateAccessibilityTool.handle(
                arguments: params.arguments, client: ascClient)
        case "list_beta_groups":
            return try await ListBetaGroupsTool.handle(
                arguments: params.arguments, client: ascClient)
        case "create_beta_group":
            return try await CreateBetaGroupTool.handle(
                arguments: params.arguments, client: ascClient)
        case "update_beta_group":
            return try await UpdateBetaGroupTool.handle(
                arguments: params.arguments, client: ascClient)
        case "delete_beta_group":
            return try await DeleteBetaGroupTool.handle(
                arguments: params.arguments, client: ascClient)
        case "add_beta_tester":
            return try await AddBetaTesterTool.handle(
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
try await Task.sleep(for: .seconds(60 * 60 * 24 * 365))
