import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum VersionLocResult {
    case success(AppStoreVersionLocalization)
    case failure(CallTool.Result)
}

/// Shared helper to find the version localization for a given app and locale.
/// Returns the localization of `appStoreVersions.data.first` — usually the most recent
/// version, which is the right target for fields that only go live with a new release
/// (description, keywords, what's new).
/// Used by update_description, update_keywords, update_whats_new, and bulk_update.
func findVersionLocalization(
    appId: String,
    locale: String,
    client: AppStoreConnectClient
) async throws -> VersionLocResult {
    let versionsResponse = try await client.send(
        Resources.v1.apps.id(appId).appStoreVersions.get()
    )
    guard let version = versionsResponse.data.first else {
        return .failure(
            .init(
                content: [.text("Error: No app store version found for app \(appId)")],
                isError: true)
        )
    }

    let versionLocsResponse = try await client.send(
        Resources.v1.appStoreVersions.id(version.id).appStoreVersionLocalizations.get(
            filterLocale: [locale]
        )
    )
    guard let loc = versionLocsResponse.data.first else {
        return .failure(
            .init(
                content: [.text("Error: No version localization found for locale \(locale)")],
                isError: true)
        )
    }

    return .success(loc)
}

/// Find the version localization on the version currently LIVE on the App Store
/// (state == .readyForSale).
///
/// Promo text is the one metadata field Apple lets you edit on a live version without a new
/// version submission — and the edit goes live immediately on the public product page.
/// `update_promo_text` should prefer this helper so the text actually propagates, instead of
/// landing on a prepared/in-review version where it stays invisible until release.
///
/// Returns `.failure` if no live version exists (brand-new app pre-launch, or app removed
/// from sale). Callers should fall back to `findVersionLocalization` in that case.
func findLiveVersionLocalization(
    appId: String,
    locale: String,
    client: AppStoreConnectClient
) async throws -> VersionLocResult {
    let versionsResponse = try await client.send(
        Resources.v1.apps.id(appId).appStoreVersions.get()
    )
    guard let liveVersion = versionsResponse.data.first(where: { v in
        v.attributes?.appStoreState == .readyForSale
    }) else {
        return .failure(
            .init(
                content: [.text(
                    "Error: No live (READY_FOR_SALE) version found for app \(appId). The app may not have shipped yet or has been removed from sale."
                )],
                isError: true)
        )
    }

    let versionLocsResponse = try await client.send(
        Resources.v1.appStoreVersions.id(liveVersion.id).appStoreVersionLocalizations.get(
            filterLocale: [locale]
        )
    )
    guard let loc = versionLocsResponse.data.first else {
        return .failure(
            .init(
                content: [.text(
                    "Error: No version localization found for locale \(locale) on the live version."
                )],
                isError: true)
        )
    }

    return .success(loc)
}
