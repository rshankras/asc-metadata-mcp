# Spec: asc-metadata-mcp — App Store Connect Metadata MCP Server

**Purpose:** Save as a spec document. Not for immediate implementation.

## Overview

A Swift MCP server focused on reading and updating App Store metadata directly from Claude Code. Pairs with Astro MCP to create a complete ASO workflow: Astro (keyword data) → Claude (optimize) → this MCP (publish to App Store Connect).

## Tech Stack

- **Swift 6+** / macOS 14+
- **[MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk)** — official SDK, stdio transport
- **[asc-swift](https://github.com/aaronsky/asc-swift)** — App Store Connect API client with JWT lifecycle management
- **StdioTransport** — for Claude Code / Claude Desktop integration

## Project Structure

```
asc-metadata-mcp/
├── Package.swift
├── Sources/
│   ├── main.swift                      # Entry point, server setup
│   ├── Config/
│   │   └── AuthConfig.swift            # Load P8 key, issuer ID, key ID
│   ├── Tools/
│   │   ├── ListAppsTool.swift          # list_apps
│   │   ├── GetMetadataTool.swift       # get_metadata
│   │   ├── UpdateNameTool.swift        # update_name
│   │   ├── UpdateKeywordsTool.swift    # update_keywords
│   │   ├── UpdateDescriptionTool.swift # update_description
│   │   ├── UpdatePromoTextTool.swift   # update_promo_text
│   │   ├── UpdateWhatsNewTool.swift    # update_whats_new
│   │   ├── ListLocalesTool.swift       # list_locales
│   │   └── BulkUpdateTool.swift        # bulk_update
│   └── Helpers/
│       └── LocaleHelper.swift          # Locale code validation
├── config.json.example                 # Template for auth config
└── README.md
```

## Package.swift

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "asc-metadata-mcp",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.9.0"),
        .package(url: "https://github.com/aaronsky/asc-swift.git", from: "4.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "asc-metadata-mcp",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "AppStoreConnect", package: "asc-swift"),
            ]
        ),
    ]
)
```

## Authentication

### Config Location
`~/.asc-metadata-mcp/config.json` (outside project, gitignored)

### Config Format
```json
{
    "issuerID": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    "privateKeyID": "XXXXXXXXXX",
    "privateKeyPath": "/Users/you/.appstoreconnect/AuthKey_XXXXXXXXXX.p8"
}
```

### How to Get These
1. Go to [App Store Connect → Users and Access → Integrations → Keys](https://appstoreconnect.apple.com/access/integrations/api)
2. Generate an API key with "App Manager" or "Admin" role
3. Download the `.p8` file (only available once!)
4. Note the Key ID and Issuer ID from the page

### JWT Lifecycle
- asc-swift handles JWT creation and auto-rotation before 20-minute expiry
- Uses ES256 algorithm (ECDSA with P-256 + SHA-256)
- No manual token management needed

## MCP Tools Specification (9 tools)

---

### 1. `list_apps`

List all apps in your App Store Connect account.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| — | — | — | No parameters |

**Returns:**
```json
[
    {
        "appId": "6753263352",
        "name": "SleepRiddle - Rest Better",
        "bundleId": "com.example.sleepriddle",
        "platform": "iOS",
        "sku": "SLEEPRIDDLE"
    }
]
```

**ASC API:** `GET /v1/apps`

---

### 2. `get_metadata`

Read current metadata for an app in a specific locale.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| appId | string | yes | App Store app ID |
| locale | string | no | Locale code (default: "en-US") |

**Returns:**
```json
{
    "appId": "6753263352",
    "locale": "en-US",
    "name": "SleepRiddle - Rest Better",
    "subtitle": "Rest Better",
    "keywords": "sleep,rest,better,quality",
    "keywordsCharCount": 28,
    "description": "Full app description...",
    "descriptionCharCount": 1234,
    "promotionalText": "Current promo text...",
    "promoTextCharCount": 45,
    "whatsNew": "Bug fixes and improvements",
    "version": "1.2.0"
}
```

**ASC API:** `GET /v1/appInfoLocalizations/{id}` + `GET /v1/appStoreVersionLocalizations/{id}`

---

### 3. `update_name`

Update app name and/or subtitle (requires new version).

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| appId | string | yes | App Store app ID |
| locale | string | no | Locale code (default: "en-US") |
| name | string | no | New app name (max 30 chars) |
| subtitle | string | no | New subtitle (max 30 chars) |
| dryRun | boolean | no | Preview changes without applying (default: false) |

**Returns:**
```json
{
    "status": "updated",
    "changes": {
        "name": { "old": "SleepRiddle - Rest Better", "new": "SleepRiddle - Rest Better", "chars": "25/30" },
        "subtitle": { "old": "Rest Better", "new": "Diary, Health Score & Insights", "chars": "29/30" }
    }
}
```

**Validation:** Reject if name >30 chars or subtitle >30 chars.
**ASC API:** `PATCH /v1/appInfoLocalizations/{id}`

---

### 4. `update_keywords`

Update the keywords field for a specific locale.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| appId | string | yes | App Store app ID |
| locale | string | no | Locale code (default: "en-US") |
| keywords | string | yes | Comma-separated keywords, no spaces |
| dryRun | boolean | no | Preview changes without applying |

**Returns:**
```json
{
    "status": "updated",
    "keywords": "quality,track,habit,hygiene,log,journal,private,hrv,heart,rate,stage,rem,deep,caffeine,night,monitor",
    "charCount": "100/100",
    "warnings": []
}
```

**Validation:**
- Reject if >100 chars
- Warn if spaces found after commas
- Warn if duplicate words detected
- Warn if plural form of existing word found

**ASC API:** `PATCH /v1/appStoreVersionLocalizations/{id}`

---

### 5. `update_description`

Update full app description.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| appId | string | yes | App Store app ID |
| locale | string | no | Locale code (default: "en-US") |
| description | string | yes | Full description text |
| dryRun | boolean | no | Preview changes without applying |

**Returns:** Confirmation with char count (max 4000).
**ASC API:** `PATCH /v1/appStoreVersionLocalizations/{id}`

---

### 6. `update_promo_text`

Update promotional text. **No app review needed** — goes live immediately.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| appId | string | yes | App Store app ID |
| locale | string | no | Locale code (default: "en-US") |
| promotionalText | string | yes | Promotional text (max 170 chars) |
| dryRun | boolean | no | Preview changes without applying |

**Returns:** Confirmation with char count (max 170).
**ASC API:** `PATCH /v1/appStoreVersionLocalizations/{id}`

---

### 7. `update_whats_new`

Update release notes / what's new text.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| appId | string | yes | App Store app ID |
| locale | string | no | Locale code (default: "en-US") |
| whatsNew | string | yes | Release notes text |
| dryRun | boolean | no | Preview changes without applying |

**Returns:** Confirmation with char count (max 4000).
**ASC API:** `PATCH /v1/appStoreVersionLocalizations/{id}`

---

### 8. `list_locales`

List all active localizations for an app.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| appId | string | yes | App Store app ID |

**Returns:**
```json
{
    "appId": "6753263352",
    "locales": [
        { "locale": "en-US", "name": "SleepRiddle - Rest Better" },
        { "locale": "es-MX", "name": "SleepRiddle - Rest Better" }
    ]
}
```

**ASC API:** `GET /v1/appInfos/{id}/appInfoLocalizations`

---

### 9. `bulk_update`

Update multiple metadata fields at once for a locale. The main tool for pushing ASO.md content.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| appId | string | yes | App Store app ID |
| locale | string | no | Locale code (default: "en-US") |
| keywords | string | no | Keywords (100 chars max) |
| description | string | no | Description (4000 chars max) |
| promotionalText | string | no | Promo text (170 chars max) |
| whatsNew | string | no | Release notes (4000 chars max) |
| dryRun | boolean | no | Preview all changes without applying |

**Returns:** Summary of all changes with before/after for each field.
**ASC API:** Multiple `PATCH` calls sequentially.

---

## Safety Features

1. **Dry-run mode** — every write tool has `dryRun` param, shows diff without changing anything
2. **Before/after diff** — every update returns old and new values
3. **Character limit validation** — rejects updates exceeding limits before calling API
4. **Keyword validation** — warns about spaces after commas, duplicates, plural forms
5. **No destructive actions** — cannot delete apps, versions, or localizations
6. **Read-first** — `get_metadata` should always be called before updates to see current state

## Claude Code Integration

### Config file: `~/.claude.json` or project `.mcp.json`

```json
{
    "mcpServers": {
        "asc-metadata": {
            "command": "/usr/local/bin/asc-metadata-mcp",
            "args": []
        }
    }
}
```

### Dream Workflow (Astro + Claude + ASC)

```
Step 1: Astro MCP
  → search_rankings, get_app_keywords, extract_competitors_keywords
  → Live keyword data with popularity, difficulty, rankings

Step 2: Claude Code
  → Analyzes data using keyword-optimizer skill
  → Generates optimized name, subtitle, keywords, description
  → Saves to ASO.md

Step 3: ASC Metadata MCP
  → bulk_update with dryRun=true (preview)
  → User approves
  → bulk_update with dryRun=false (publish)
  → Metadata live on App Store
```

## API Endpoint Summary

| Tool | ASC Endpoint | Method |
|------|-------------|--------|
| list_apps | `/v1/apps` | GET |
| get_metadata | `/v1/appInfoLocalizations/{id}` + `/v1/appStoreVersionLocalizations/{id}` | GET |
| update_name | `/v1/appInfoLocalizations/{id}` | PATCH |
| update_keywords | `/v1/appStoreVersionLocalizations/{id}` | PATCH |
| update_description | `/v1/appStoreVersionLocalizations/{id}` | PATCH |
| update_promo_text | `/v1/appStoreVersionLocalizations/{id}` | PATCH |
| update_whats_new | `/v1/appStoreVersionLocalizations/{id}` | PATCH |
| list_locales | `/v1/appInfos/{id}/appInfoLocalizations` | GET |
| bulk_update | Multiple PATCH calls | PATCH |

## Implementation Order

1. `Package.swift` — dependencies (MCP Swift SDK + asc-swift)
2. `AuthConfig.swift` — load credentials from ~/.asc-metadata-mcp/config.json
3. `main.swift` — server setup with StdioTransport, register all tools
4. `list_apps` — simplest tool, validates auth works end-to-end
5. `get_metadata` — read current state for any app + locale
6. `list_locales` — prerequisite for cross-locale updates
7. `update_keywords` — most frequent use case with Astro workflow
8. `update_promo_text` — no review needed, quick win for testing
9. `update_description` + `update_whats_new` — version-level metadata
10. `update_name` — name/subtitle changes (less frequent, higher risk)
11. `bulk_update` — convenience wrapper combining multiple updates
12. Add dry-run mode + validation to all write tools

## Testing Checklist

- [ ] `swift build` succeeds
- [ ] `list_apps` returns your apps (validates auth)
- [ ] `get_metadata` for SleepRiddle matches what's in App Store Connect
- [ ] `update_promo_text` with dryRun=true shows correct diff
- [ ] `update_promo_text` with dryRun=false actually updates (verify in ASC)
- [ ] `update_keywords` validates character count and warns on issues
- [ ] `bulk_update` handles multiple fields in one call
- [ ] Cross-locale: update es-MX keywords separately from en-US
- [ ] Integration test: Astro data → Claude optimizes → this MCP pushes

## References

- [MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk)
- [asc-swift](https://github.com/aaronsky/asc-swift)
- [App Store Connect API Docs](https://developer.apple.com/documentation/appstoreconnectapi)
- [appInfoLocalizations](https://developer.apple.com/documentation/appstoreconnectapi/app_information/app_info_localizations)
- [appStoreVersionLocalizations](https://developer.apple.com/documentation/appstoreconnectapi/app_store/app_store_version_localizations)
- [Creating MCP Servers in Swift](https://artemnovichkov.com/blog/creating-mcp-servers-in-swift)
