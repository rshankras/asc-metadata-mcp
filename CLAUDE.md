# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Swift MCP (Model Context Protocol) server that lets Claude Code manage the full App Store Connect lifecycle. It exposes 60 tools over stdio transport across 10 categories: metadata (10), in-app events (5), analytics/performance (4), sales/finance (2), customer reviews (4), custom product pages (5), product page optimization/A/B testing (5), in-app purchases (5), subscriptions (5), pricing/availability (4), release management (3), app configuration (3), and beta testing/TestFlight (5).

## Build

```bash
swift build -c release
```

No tests, linting, or CI are configured.

## Architecture

**Entry point:** `Sources/main.swift` — loads auth config, creates an `AppStoreConnectClient`, sets up MCP `Server` with stdio transport, and routes tool calls via a switch statement.

**Tool pattern:** Each tool is an `enum` in `Sources/Tools/` with:
- A static `tool` property defining MCP metadata (name, description, inputSchema)
- A static async `handle(arguments:client:)` function

All write tools support `dryRun: true` and return old/new values for confirmation.

**Two ASC entity types for metadata:**
- **AppInfoLocalizations** — name, subtitle (via `UpdateNameTool`)
- **AppStoreVersionLocalizations** — keywords, description, promo text, what's new (via other update tools)

`VersionLocalizationHelper` is shared across tools that need to look up the active version's localization.

**Analytics & Performance tools:**
- `GetPerfMetricsTool` — calls `perfPowerMetrics` API for iOS performance/power data with regression insights
- `GetDiagnosticsTool` — fetches diagnostic signatures from builds, auto-resolves latest valid build
- `SetupAnalyticsReportsTool` — creates ONGOING analytics report requests (one-time prerequisite)
- `GetAnalyticsReportTool` — 5-step API chain: finds report request → lists reports → gets instances → gets segments → downloads & parses CSV

**In-App Event tools:**
- `ListAppEventsTool` — lists events for an app with nested localizations, optional eventState filter (client-side)
- `CreateAppEventTool` — creates an event with optional initial localization in the same call; supports badge, priority, purpose, territorySchedules
- `UpdateAppEventTool` — fetches current event then patches changed attributes; shows old/new diffs
- `DeleteAppEventTool` — fetches event details for confirmation then deletes
- `UpdateEventLocalizationTool` — creates or updates event localization (auto-detects via locale match); validates locale and character limits

**Sales & Finance tools:**
- `GetSalesReportTool` — downloads sales/trends reports via `client.download()`, parses gzip-compressed TSV
- `GetFinanceReportTool` — downloads monthly financial settlement reports via `client.download()`, parses gzip-compressed TSV

**Customer Reviews tools:**
- `ListReviewsTool` — lists reviews with filtering by rating, territory, response status; sorting by rating/date
- `GetReviewTool` — gets a single review with its developer response
- `RespondToReviewTool` — creates a developer response to a review; shows review context
- `DeleteReviewResponseTool` — deletes a developer response

**Custom Product Pages tools:**
- `ListCustomPagesTool` — lists custom product pages with versions and states
- `CreateCustomPageTool` — creates a new custom product page
- `UpdateCustomPageTool` — updates name or visibility
- `DeleteCustomPageTool` — deletes a custom product page
- `CreateCustomPageVersionTool` — creates a new version for localized content updates

**Product Page Optimization tools (A/B Testing):**
- `ListExperimentsTool` — lists experiments with optional state filter
- `CreateExperimentTool` — creates a new experiment with platform and traffic proportion
- `UpdateExperimentTool` — updates name, traffic proportion, or starts/stops experiment
- `DeleteExperimentTool` — deletes an experiment
- `CreateExperimentTreatmentTool` — adds a treatment variant to an experiment

**In-App Purchase tools:**
- `ListIAPTool` — lists IAPs with state/type filters
- `GetIAPTool` — gets detailed IAP info
- `CreateIAPTool` — creates consumable, non-consumable, or non-renewing subscription IAP
- `UpdateIAPTool` — updates name, review note, family sharing
- `DeleteIAPTool` — deletes an IAP

**Subscription tools:**
- `ListSubscriptionGroupsTool` — lists subscription groups with nested subscriptions
- `CreateSubscriptionGroupTool` — creates a new subscription group
- `ListSubscriptionsTool` — lists subscriptions within a group
- `CreateSubscriptionTool` — creates a subscription with period, group level, etc.
- `UpdateSubscriptionTool` — updates subscription metadata

**Pricing & Availability tools:**
- `GetAppPricingTool` — gets current pricing schedule with manual/automatic prices
- `ListPricePointsTool` — lists available price tiers for a territory
- `GetAvailabilityTool` — gets territory availability with status details
- `UpdateAvailabilityTool` — updates territory availability settings

**Release Management tools:**
- `CreatePhasedReleaseTool` — enables phased release for a version
- `UpdatePhasedReleaseTool` — pauses, resumes, or completes a phased release
- `DeletePhasedReleaseTool` — removes phased release (immediate 100% rollout)

**App Configuration tools:**
- `GetAgeRatingTool` — gets age rating declaration via appInfo chain
- `UpdateAgeRatingTool` — updates content descriptors and age rating overrides
- `UpdateAccessibilityTool` — creates or updates accessibility declarations (VoiceOver, captions, etc.)

**Beta Testing / TestFlight tools:**
- `ListBetaGroupsTool` — lists TestFlight groups with optional filters
- `CreateBetaGroupTool` — creates a beta group with public link and feedback settings
- `UpdateBetaGroupTool` — updates group settings
- `DeleteBetaGroupTool` — deletes a beta group
- `AddBetaTesterTool` — adds a tester by email to a group

**Helpers:**
- `LocaleHelper` validates locales against 35+ supported App Store locales and provides keyword validation (100 char limit, duplicate/plural/space warnings)
- `CSVParser` parses tab-separated analytics report data downloaded from Apple's pre-signed URLs

## Key Dependencies

- `MCP` from [modelcontextprotocol/swift-sdk](https://github.com/modelcontextprotocol/swift-sdk) (v0.11.0) — MCP protocol
- `AppStoreConnect` from [aaronsky/asc-swift](https://github.com/aaronsky/asc-swift) (v1.5.0) — App Store Connect API client

## Configuration

Auth config lives at `~/.asc-metadata-mcp/config.json` with `issuerID`, `privateKeyID`, and `privateKeyPath` (path to `.p8` key file). See `config.json.example`.

## Character Limits (enforced in tools)

Name: 30, Subtitle: 30, Keywords: 100, Description: 4000, Promo Text: 170, What's New: 4000.

**Event localization limits:** Name: 30, Short Description: 50, Long Description: 120.

## Adding a New Tool

1. Create `Sources/Tools/NewTool.swift` as an `enum` with static `tool` and `handle()`
2. Register in `main.swift`: add to the `ListTools` array and `CallTool` switch
