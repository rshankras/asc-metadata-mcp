import AppStoreConnect
import AppStoreAPI
import Foundation
import MCP

enum VersionLocResult {
    case success(AppStoreVersionLocalization)
    case failure(CallTool.Result)
}

/// Shared helper to find the version localization for a given app and locale.
/// Used by update_description, update_promo_text, update_whats_new, and bulk_update.
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
