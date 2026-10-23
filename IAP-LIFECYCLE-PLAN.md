# Plan — Full In-App Purchase Lifecycle via MCP

**Goal:** make the ASC MCP able to take a non-consumable IAP from *created* all the way to *ready-to-submit* and *submitted* — price, localization, review screenshot, availability, and submission — with **no manual App Store Connect clicking**.

**Status:** draft spec, ready to implement. Nothing here is built yet.

> Drafted 2026-07-01 while shipping the "Crowdroar Pro" IAP (`com.rshankar.crowdroar.pro`, appId `6786246010`). Today `create_iap` only creates the product *shell*; price/localization/screenshot/submission all fall back to manual ASC. This plan closes that gap.

---

## 1. Current state

**IAP tools that exist:** `create_iap`, `update_iap` (name / reviewNote / familySharable only), `get_iap`, `list_iap`, `delete_iap`, `list_price_points`, `get_app_pricing`.

**Gaps (why an IAP still needs manual ASC):** a freshly `create_iap`'d product is `MISSING_METADATA`. To reach `READY_TO_SUBMIT` it needs, at minimum:

| Requirement | Endpoint | Tool today |
|---|---|---|
| Price (≥1 price schedule) | `POST /v1/inAppPurchasePriceSchedules` | ❌ missing |
| Localization (name + description, ≥1 locale) | `POST /v1/inAppPurchaseLocalizations` | ❌ missing |
| Review screenshot | `POST /v1/inAppPurchaseAppStoreReviewScreenshots` (+ upload + commit) | ❌ missing |
| Availability (territories) | `POST /v1/inAppPurchaseAvailabilities` | ❌ missing (often defaults OK) |
| Submit for review | `POST /v1/inAppPurchaseSubmissions` | ❌ missing |

All five endpoints **and their `…CreateRequest` entities exist in the vendored SDK** (`asc-swift` → `AppStoreAPI`), verified 2026-07-01. So this is purely additive tool work — no SDK changes.

---

## 2. Lifecycle order (dependency graph)

```
create_iap  ─┬─►  create_iap_localization   (name + description)
             ├─►  set_iap_price             (price schedule)
             ├─►  upload_iap_screenshot     (reserve → upload → commit)
             └─►  set_iap_availability      (optional — territories)
                        │
                        ▼
                 submit_iap_for_review      (requires the 3 above complete)
```

`get_iap` / `list_iap` are the verification read-backs (watch `state` go `MISSING_METADATA → READY_TO_SUBMIT → WAITING_FOR_REVIEW`).

---

## 3. Tool + registration pattern (how every tool is wired)

Each tool is one file `Sources/Tools/<Name>Tool.swift` with:

```swift
import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum <Name>Tool {
    static let tool = Tool(name: "<snake_name>", description: "...",
        inputSchema: .object([ "type": "object", "properties": .object([ ... ]),
                               "required": .array([ ... ]) ]))

    static func handle(arguments: [String: Value]?, client: AppStoreConnectClient)
        async throws -> CallTool.Result {
        // 1. parse + validate args (see CreateIAPTool for the guard-let idiom)
        // 2. honor `dryRun` (return a preview dict before any write)
        // 3. build the …CreateRequest, `try await client.send(Resources.v1.….post(request))`
        // 4. return JSON result (status/ids)
    }
}
```

**Register in `Sources/main.swift` (two edits per tool):**
1. Add `<Name>Tool.tool,` to the `tools` array (~line 21+).
2. Add `case "<snake_name>": return try await <Name>Tool.handle(arguments: arguments, client: client)` to the dispatch `switch` (~line 95+).

Copy `CreateIAPTool.swift` as the template — it already shows arg parsing, `dryRun`, the request build, and `client.send(Resources.v2.inAppPurchases.post(...))`.

**Every write tool must support `dryRun: true`** (preview, no write) — matches the house style and is how we de-risk against a live account.

---

## 4. New tools — specs

### 4.1 `set_iap_price`  — the key one

- **Endpoint:** `POST /v1/inAppPurchasePriceSchedules` → `Resources.v1.inAppPurchasePriceSchedules.post(...)`
- **Inputs:** `iapId` (req), `pricePointId` (req — from `list_price_points`), `baseTerritory` (default `"USA"`), `startDate` (optional; nil = effective immediately), `dryRun`.
- **Request shape** (`InAppPurchasePriceScheduleCreateRequest`): the tricky "inline-create + `included`" pattern — mirror `UpdateAvailabilityTool` which does the same for **app** price schedules.

```swift
let priceRef = "${price1}"   // client temp id linking manualPrices ↔ included
let request = InAppPurchasePriceScheduleCreateRequest(
    data: .init(
        type: .inAppPurchasePriceSchedules,
        relationships: .init(
            inAppPurchase:  .init(data: .init(type: .inAppPurchases, id: iapId)),
            baseTerritory:  .init(data: .init(type: .territories, id: baseTerritory)),
            manualPrices:   .init(data: [ .init(type: .inAppPurchasePrices, id: priceRef) ])
        )
    ),
    included: [
        // NOTE: confirm the exact `IncludedItem` enum case name for InAppPurchasePriceInlineCreate
        .inAppPurchasePriceInlineCreate(.init(
            type: .inAppPurchasePrices,
            id: priceRef,
            attributes: .init(startDate: startDate, endDate: nil),
            relationships: .init(
                inAppPurchasePricePoint: .init(
                    data: .init(type: .inAppPurchasePricePoints, id: pricePointId))
            )
        ))
    ]
)
```

- **Gotchas:** `baseTerritory` is **required** by the entity. The price-point id is territory-specific (the `$6.99` id already encodes USA). The `manualPrices` id **must** equal the `included` item's `id`. Check the `included` array element type (`InAppPurchasePriceScheduleCreateRequest.IncludedItem`) for the correct enum case.
- **Verify `IncludedItem` shape:** open `…/Entities/InAppPurchasePriceScheduleCreateRequest.swift` for the `IncludedItem` enum.

### 4.2 `create_iap_localization`

- **Endpoint:** `POST /v1/inAppPurchaseLocalizations`
- **Inputs:** `iapId` (req), `locale` (req, e.g. `"en-US"`), `name` (req — the customer-facing display name), `description` (optional), `dryRun`.

```swift
let request = InAppPurchaseLocalizationCreateRequest(
    data: .init(
        type: .inAppPurchaseLocalizations,
        attributes: .init(name: name, locale: locale, description: description),
        relationships: .init(
            inAppPurchaseV2: .init(data: .init(type: .inAppPurchases, id: iapId)))
    )
)
```
- **Note:** display `name` ≤ 30 chars, `description` ≤ 45 chars (ASC limits — validate + return a clear error).

### 4.3 `upload_iap_screenshot`  — the hard one (3-step asset upload)

No asset-upload precedent exists in the repo yet; this is the most involved tool. ASC asset uploads are always **reserve → PUT bytes → commit**.

- **Inputs:** `iapId` (req), `filePath` (req — local path to a PNG/JPEG review screenshot), `dryRun`.

**Step 1 — reserve** (`POST /v1/inAppPurchaseAppStoreReviewScreenshots`):
```swift
let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
let request = InAppPurchaseAppStoreReviewScreenshotCreateRequest(
    data: .init(
        type: .inAppPurchaseAppStoreReviewScreenshots,
        attributes: .init(fileSize: data.count, fileName: (filePath as NSString).lastPathComponent),
        relationships: .init(
            inAppPurchaseV2: .init(data: .init(type: .inAppPurchases, id: iapId)))
    )
)
let created = try await client.send(Resources.v1.inAppPurchaseAppStoreReviewScreenshots.post(request)).data
// created.id, created.attributes?.uploadOperations : [UploadOperation]
```

**Step 2 — upload bytes** to each `UploadOperation` (raw `URLSession`, NOT the typed ASC client):
```swift
for op in created.attributes?.uploadOperations ?? [] {
    // op.method (usually "PUT"), op.url, op.requestHeaders [{name,value}], op.offset, op.length
    var req = URLRequest(url: URL(string: op.url!)!)
    req.httpMethod = op.method
    for h in op.requestHeaders ?? [] { req.setValue(h.value, forHTTPHeaderField: h.name!) }
    let chunk = data.subdata(in: op.offset! ..< (op.offset! + op.length!))
    _ = try await URLSession.shared.upload(for: req, from: chunk)
}
```

**Step 3 — commit** (`PATCH /v1/inAppPurchaseAppStoreReviewScreenshots/{id}`) with the MD5:
```swift
import Crypto   // swift-crypto — ADD to Package.swift if not present
let md5 = Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
let patch = InAppPurchaseAppStoreReviewScreenshotUpdateRequest(
    data: .init(type: .inAppPurchaseAppStoreReviewScreenshots, id: created.id,
                attributes: .init(uploaded: true, sourceFileChecksum: md5)))   // confirm `uploaded` field name
_ = try await client.send(Resources.v1.inAppPurchaseAppStoreReviewScreenshots.withID(created.id).patch(patch))
```
- **Confirm:** the exact `UploadOperation` field names (`url`/`method`/`requestHeaders`/`offset`/`length`) in `Entities/UploadOperation.swift`, and that the UpdateRequest attributes has `uploaded` (grep only surfaced `sourceFileChecksum`).
- **Dependency:** MD5 needs `swift-crypto` (`import Crypto`) — check `Package.swift`; add `.package(url: "https://github.com/apple/swift-crypto", from: "3.0.0")` + the `Crypto` target dep if missing. (Or shell out to `md5`/use CryptoKit — CryptoKit is macOS-only but this MCP runs on macOS, so `import CryptoKit` may be simplest and dependency-free.)
- Poll `assetDeliveryState` via `get`/`list` until `COMPLETE` before submitting.

### 4.4 `set_iap_availability`  — optional (territories)

- **Endpoint:** `POST /v1/inAppPurchaseAvailabilities`
- **Inputs:** `iapId` (req), `territories` (array of territory ids, e.g. `["USA","GBR"]`), `availableInNewTerritories` (default `true`), `dryRun`.
```swift
let request = InAppPurchaseAvailabilityCreateRequest(
    data: .init(
        type: .inAppPurchaseAvailabilities,
        attributes: .init(isAvailableInNewTerritories: availableInNewTerritories),
        relationships: .init(
            inAppPurchase: .init(data: .init(type: .inAppPurchases, id: iapId)),
            availableTerritories: .init(data: territories.map { .init(type: .territories, id: $0) }))
    )
)
```
- Often a new IAP defaults to all territories → treat as optional/skip unless restricting.

### 4.5 `submit_iap_for_review`

- **Endpoint:** `POST /v1/inAppPurchaseSubmissions`
- **Inputs:** `iapId` (req), `dryRun`.
```swift
let request = InAppPurchaseSubmissionCreateRequest(
    data: .init(type: .inAppPurchaseSubmissions,
                relationships: .init(
                    inAppPurchaseV2: .init(data: .init(type: .inAppPurchases, id: iapId))))
)
_ = try await client.send(Resources.v1.inAppPurchaseSubmissions.post(request))
```
- **Precondition:** the IAP must be `READY_TO_SUBMIT` (price + ≥1 localization + screenshot `COMPLETE`). If ASC rejects with a state error, surface it clearly so the caller knows which piece is missing.

### 4.6 (Optional read helpers)
- `list_iap_localizations` (`GET …/inAppPurchases/{id}/inAppPurchaseLocalizations`) and screenshot-status read, to verify without leaving the MCP. `get_iap` may already include enough via `include=`.

---

## 5. Build · deploy · use

```bash
cd /Users/ravishankar/Work/MyApps/asc-metadata-mcp
swift build -c release
# the running server is .build/release/asc-metadata-mcp — restart it so new tools load
```
**⚠️ Session caveat:** Claude Code fixes the MCP tool list at connection time. After rebuilding, **restart Claude Code / reconnect the MCP** — new tools won't appear in an already-open session.

---

## 6. Test checklist (against Crowdroar, low-risk order)

Concrete values: appId `6786246010` · productId `com.rshankar.crowdroar.pro` · $6.99 pricePointId `eyJzIjoiNjc4NjI0NjAxMCIsInQiOiJVU0EiLCJwIjoiMTAwODgifQ` · locale `en-US` · baseTerritory `USA`.

1. `create_iap` (dryRun → apply) — done already? verify with `list_iap`.
2. `create_iap_localization` dryRun → apply → `get_iap` shows the localization.
3. `set_iap_price` dryRun → apply → `get_iap`/`get_app_pricing` shows $6.99.
4. `upload_iap_screenshot` with a real PNG → poll until `assetDeliveryState == COMPLETE`.
5. `get_iap` → expect `state == READY_TO_SUBMIT`.
6. `submit_iap_for_review` (only when confident — this is the outward-facing one).

Always `dryRun` first on every write; verify state transitions with `get_iap` between steps.

---

## 6a. Appendix — Beyond IAP: full app-store submission via MCP

The same question applies to the *app* listing. Current coverage:

**Already covered (text metadata):** `update_name` (title + subtitle), `update_keywords`, `update_description`, `update_promo_text`, `update_whats_new`, `bulk_update`, `get_metadata`, `create_version`, `update_age_rating`, `update_availability`. → title / subtitle / keywords / description / promo / what's-new all go through the MCP today.

**Still missing (binary assets — the same reserve→upload→commit machinery as §4.3):**

| Item | Endpoint chain | SDK entities (confirmed present) |
|---|---|---|
| **App screenshots** | create `appScreenshotSets` (per display size) → `POST /v1/appScreenshots` (reserve) → PUT bytes → PATCH commit(MD5) | `AppScreenshotSetCreateRequest`, `AppScreenshotCreateRequest` |
| **App preview videos** | `appPreviewSets` → `appPreviews` reserve → upload → commit | `AppPreviewSetCreateRequest`, `AppPreviewCreateRequest` |
| **App icon / version localizations** | `AppStoreVersionLocalization*`, `AppInfoLocalization*` | present |

**Recommendation:** factor the §4.3 upload into a reusable helper — e.g. `AssetUpload.reserveUploadCommit(reserveRequest:, fileData:, patch:)` — then `upload_iap_screenshot`, `upload_app_screenshot`, and `upload_app_preview` are thin wrappers over it. Screenshot display-size targeting (e.g. `APP_IPHONE_67`) is the only extra input for app screenshots vs. the IAP one. Do the IAP screenshot first (smallest scope), extract the helper, then app screenshots/previews reuse it.

Once that helper exists, **the entire submission — text + all assets + IAP — goes through the MCP.**

## 7. Gotchas summary
- Price schedule = inline-create + `included` + **required `baseTerritory`**; the `manualPrices` id must match the `included` id. Mirror `UpdateAvailabilityTool`.
- Screenshot = 3-step reserve/PUT/commit with an **MD5** checksum; use `CryptoKit` (macOS) to avoid a new dependency.
- Confirm exact field names before coding: `IncludedItem` enum case (§4.1), `UploadOperation` fields + `uploaded` on the screenshot UpdateRequest (§4.3).
- Localization char limits: name ≤ 30, description ≤ 45.
- Submission preconditions — return ASC's state error verbatim so the missing piece is obvious.
- Keep `dryRun` on all writes; keep the JSON result shape consistent with existing tools.
