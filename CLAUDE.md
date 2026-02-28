# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Swift MCP (Model Context Protocol) server that lets Claude Code read and update App Store Connect metadata, check app analytics and performance, and download sales & finance reports. It exposes 16 tools over stdio transport: metadata tools (list_apps, get_metadata, update_name, update_keywords, update_description, update_promo_text, update_whats_new, list_locales, bulk_update, create_version), analytics/performance tools (get_perf_metrics, get_diagnostics, setup_analytics_reports, get_analytics_report), and sales/finance tools (get_sales_report, get_finance_report).

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

**Sales & Finance tools:**
- `GetSalesReportTool` — downloads sales/trends reports via `client.download()`, parses gzip-compressed TSV
- `GetFinanceReportTool` — downloads monthly financial settlement reports via `client.download()`, parses gzip-compressed TSV

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

## Adding a New Tool

1. Create `Sources/Tools/NewTool.swift` as an `enum` with static `tool` and `handle()`
2. Register in `main.swift`: add to the `ListTools` array and `CallTool` switch
