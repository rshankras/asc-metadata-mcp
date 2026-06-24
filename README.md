# asc-metadata-mcp

> App Store Connect as MCP tools — manage metadata, analytics, reviews, IAP, subscriptions, and more directly from Claude Code or Claude Desktop.

[![Swift 6](https://img.shields.io/badge/Swift-6-orange.svg)](https://swift.org)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue.svg)](https://developer.apple.com/macos/)
[![MCP](https://img.shields.io/badge/MCP-compatible-green.svg)](https://modelcontextprotocol.io)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A native Swift [MCP server](https://modelcontextprotocol.io) that exposes **65+ App Store Connect API operations** as structured tools — so Claude can read and write your App Store presence without shell commands, browser sessions, or copy-paste.

**Part of the indie Apple developer stack:**
- **[asc-metadata-mcp](https://github.com/rshankras/asc-metadata-mcp)** ← you are here — the ASC integration layer
- **[indie-app-autopilot](https://github.com/rshankras/indie-app-autopilot)** — agent pipeline from GitHub issue → App Store
- **[claude-code-apple-skills](https://github.com/rshankras/claude-code-apple-skills)** — 139 Apple development skills for Claude Code

## What you can do

Ask Claude: *"Update the keywords for all my apps based on this week's search trends"*
→ Claude calls `list_apps`, `get_metadata`, then `update_keywords` for each.

Ask Claude: *"Which app had the biggest download drop this week?"*
→ Claude calls `get_sales_report` and `get_analytics_report`, then ranks them.

Ask Claude: *"Reply to all 1-star reviews that mention crashes"*
→ Claude calls `list_reviews`, filters by rating and content, calls `respond_to_review` for each.

All write tools support **`dryRun: true`** — Claude shows exactly what it would change before touching anything.

## Setup

### 1. Generate App Store Connect API Key

1. Go to [App Store Connect → Users and Access → Integrations → Keys](https://appstoreconnect.apple.com/access/integrations/api)
2. Generate an API key with **App Manager** or **Admin** role
3. Download the `.p8` file (only available once)
4. Note the Key ID and Issuer ID

### 2. Create Config

```bash
mkdir -p ~/.asc-metadata-mcp
cat > ~/.asc-metadata-mcp/config.json << 'EOF'
{
    "issuerID": "YOUR_ISSUER_ID",
    "privateKeyID": "YOUR_KEY_ID",
    "privateKeyPath": "/Users/you/.appstoreconnect/AuthKey_XXXXXXXX.p8",
    "vendorNumber": "YOUR_VENDOR_NUMBER"
}
EOF
```

`vendorNumber` is optional — default for `get_sales_report` and `get_finance_report`. Find it in App Store Connect under Payments and Financial Reports (not available via API).

### 3. Build

```bash
git clone https://github.com/rshankras/asc-metadata-mcp.git
cd asc-metadata-mcp
swift build -c release
```

### 4. Add to Claude Code

`~/.claude.json` or project `.mcp.json`:

```json
{
    "mcpServers": {
        "asc-metadata": {
            "command": "/path/to/asc-metadata-mcp/.build/release/asc-metadata-mcp",
            "args": []
        }
    }
}
```

For Claude Desktop, add the same block to `~/Library/Application Support/Claude/claude_desktop_config.json`.

## Tools (65+)

### Apps & Metadata

| Tool | Description |
|------|-------------|
| `list_apps` | List all apps in your account |
| `get_metadata` | Read metadata for an app + locale |
| `list_locales` | List active localizations |
| `update_name` | Update app name / subtitle |
| `update_keywords` | Update keywords (validates 100-char limit per locale) |
| `update_description` | Update full description |
| `update_promo_text` | Update promo text (goes live immediately, no review needed) |
| `update_whats_new` | Update release notes |
| `bulk_update` | Update multiple metadata fields in one call |
| `create_version` | Create a new App Store version |
| `update_accessibility` | Update accessibility metadata |
| `update_age_rating` | Update age rating declarations |
| `get_age_rating` | Read current age rating |
| `get_app_pricing` | Read pricing and availability |
| `update_availability` | Update territory availability |
| `list_price_points` | List available price points |

All write tools support `dryRun: true` to preview changes before committing.

### Reviews

| Tool | Description |
|------|-------------|
| `list_reviews` | List customer reviews (filter by rating, territory) |
| `get_review` | Get a specific review |
| `respond_to_review` | Post or update a review response |
| `delete_review_response` | Delete an existing response |

### In-App Purchases

| Tool | Description |
|------|-------------|
| `list_iap` | List all in-app purchases |
| `get_iap` | Get details for a specific IAP |
| `create_iap` | Create a new in-app purchase |
| `update_iap` | Update IAP details |
| `delete_iap` | Delete an in-app purchase |

### Subscriptions

| Tool | Description |
|------|-------------|
| `list_subscription_groups` | List subscription groups |
| `list_subscriptions` | List subscriptions in a group |
| `create_subscription_group` | Create a subscription group |
| `create_subscription` | Create a subscription product |
| `update_subscription` | Update subscription details |

### Beta Testing

| Tool | Description |
|------|-------------|
| `list_beta_groups` | List TestFlight beta groups |
| `create_beta_group` | Create a beta group |
| `update_beta_group` | Update group settings |
| `delete_beta_group` | Delete a beta group |
| `add_beta_tester` | Add a tester to a group |
| `list_beta_feedback_crashes` | Crash feedback from beta testers |
| `list_beta_feedback_screenshots` | Screenshot feedback from beta testers |

### Product Page Optimization (Experiments)

| Tool | Description |
|------|-------------|
| `list_experiments` | List A/B experiments |
| `create_experiment` | Create a new experiment |
| `create_experiment_treatment` | Add a treatment variant |
| `update_experiment` | Update experiment settings |
| `delete_experiment` | Delete an experiment |

### Custom Product Pages

| Tool | Description |
|------|-------------|
| `list_custom_pages` | List custom product pages |
| `create_custom_page` | Create a custom product page |
| `create_custom_page_version` | Create a version of a page |
| `update_custom_page` | Update custom page details |
| `delete_custom_page` | Delete a custom page |

### In-App Events

| Tool | Description |
|------|-------------|
| `list_app_events` | List in-app events |
| `create_app_event` | Create an in-app event |
| `update_app_event` | Update event details |
| `update_event_localization` | Update event localization |
| `delete_app_event` | Delete an in-app event |

### Phased Release

| Tool | Description |
|------|-------------|
| `create_phased_release` | Enable phased release for a version |
| `update_phased_release` | Pause, resume, or complete phased rollout |
| `delete_phased_release` | Cancel phased release |

### Webhooks

| Tool | Description |
|------|-------------|
| `list_webhooks` | List configured webhooks |
| `create_webhook` | Create a webhook |
| `update_webhook` | Update webhook URL / events |
| `delete_webhook` | Delete a webhook |
| `ping_webhook` | Send a test ping |

### Analytics & Performance

| Tool | Description |
|------|-------------|
| `setup_analytics_reports` | One-time setup to enable analytics collection |
| `get_analytics_report` | Download analytics data (engagement, usage, commerce) |
| `get_perf_metrics` | Performance & power metrics with regression detection |
| `get_diagnostics` | Top diagnostic signatures (hangs, disk writes, slow launches) |

Analytics reports require a one-time setup, then 24–48 hours for data to appear:
```
1. setup_analytics_reports   → run once
2. get_analytics_report      → list available reports (omit reportName)
3. get_analytics_report      → download by reportName
```
`get_perf_metrics` and `get_diagnostics` work immediately with no setup.

### Sales & Finance

| Tool | Description |
|------|-------------|
| `get_sales_report` | Units, proceeds, refunds, subscriptions (next-day) |
| `get_finance_report` | Monthly settlement reports by region |

Both require your vendor number (from App Store Connect → Payments and Financial Reports).

## Architecture

Built on the [official MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk) with StdioTransport and [asc-swift](https://github.com/aaronsky/asc-swift) for the App Store Connect API client (JWT lifecycle managed automatically).

## Related

| Repo | What it is |
|------|-----------|
| [indie-app-autopilot](https://github.com/rshankras/indie-app-autopilot) | Agent pipeline: GitHub issue → tested PR → TestFlight → App Store |
| [claude-code-apple-skills](https://github.com/rshankras/claude-code-apple-skills) | 139 Apple development skills for Claude Code |

## License

MIT
