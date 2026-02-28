# asc-metadata-mcp

A Swift MCP server for reading and updating App Store Connect metadata directly from Claude Code.

## Setup

### 1. Generate App Store Connect API Key

1. Go to [App Store Connect → Users and Access → Integrations → Keys](https://appstoreconnect.apple.com/access/integrations/api)
2. Generate an API key with "App Manager" or "Admin" role
3. Download the `.p8` file (only available once!)
4. Note the Key ID and Issuer ID

### 2. Create Config

```bash
mkdir -p ~/.asc-metadata-mcp
cat > ~/.asc-metadata-mcp/config.json << 'EOF'
{
    "issuerID": "YOUR_ISSUER_ID",
    "privateKeyID": "YOUR_KEY_ID",
    "privateKeyPath": "/path/to/AuthKey_XXXXXXXX.p8"
}
EOF
```

### 3. Build

```bash
swift build -c release
```

### 4. Add to Claude Code

Add to `~/.claude.json` or project `.mcp.json`:

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

## Tools

### Metadata

| Tool | Description |
|------|------------|
| `list_apps` | List all apps in your account |
| `get_metadata` | Read metadata for an app + locale |
| `update_name` | Update app name/subtitle |
| `update_keywords` | Update keywords with validation |
| `update_description` | Update full description |
| `update_promo_text` | Update promo text (live immediately) |
| `update_whats_new` | Update release notes |
| `list_locales` | List active localizations |
| `bulk_update` | Update multiple fields at once |
| `create_version` | Create a new App Store version |

All write tools support `dryRun: true` to preview changes.

### Analytics & Performance

| Tool | Description |
|------|------------|
| `get_perf_metrics` | Performance & power metrics with regression/improvement insights (iOS) |
| `get_diagnostics` | Top diagnostic signatures (hangs, disk writes, launches) for a build |
| `setup_analytics_reports` | One-time setup to enable analytics report collection |
| `get_analytics_report` | Download and parse analytics report data (engagement, usage, commerce) |

#### Analytics Workflow

Analytics reports require a one-time setup, then a 24-48 hour wait for data:

```
1. setup_analytics_reports  → enables ongoing collection
2. get_analytics_report     → list available reports (omit reportName)
3. get_analytics_report     → download a specific report by name
```

`get_perf_metrics` and `get_diagnostics` work immediately with no setup required.

### Sales & Finance

| Tool | Description |
|------|------------|
| `get_sales_report` | Download sales & trends reports (units, proceeds, refunds, subscriptions) |
| `get_finance_report` | Download monthly financial settlement reports (payments, proceeds by region) |

Sales reports are available next-day. Finance reports are available after Apple processes the monthly payment cycle. Both require your vendor number from App Store Connect (Payments & Financial Reports).
