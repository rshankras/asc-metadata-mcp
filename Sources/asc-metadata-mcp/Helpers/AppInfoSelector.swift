import AppStoreAPI

/// Selects the right `AppInfo` from the list returned by `GET /v1/apps/{id}/appInfos`.
///
/// An app has multiple `AppInfo` records — one per state. The API doesn't guarantee an order,
/// and `data.first` is often the live `READY_FOR_DISTRIBUTION` record (read-only). Writing to
/// its localization fails with a generic `AppStoreConnect.ResponseError`. Reads against it
/// silently return live-version data, which may not be what the caller expects when a prepared
/// version exists.
enum AppInfoSelector {
    /// States in which an `AppInfo`'s localizations can be modified.
    static let editableStates: [AppInfo.Attributes.State] = [
        .prepareForSubmission,
        .developerRejected,
        .rejected,
        .readyForReview,
    ]

    /// Returns the `AppInfo` in an editable state, or `nil` if none exists.
    /// Use this for **writes** (PATCH) — if it returns `nil`, fail fast.
    static func findEditable(in appInfos: [AppInfo]) -> AppInfo? {
        appInfos.first { info in
            guard let state = info.attributes?.state else { return false }
            return editableStates.contains(state)
        }
    }

    /// Returns the editable `AppInfo` if it exists, otherwise falls back to `data.first`.
    /// Use this for **reads** — preferring the prepared version when one is in progress.
    static func findPreferredOrFirst(in appInfos: [AppInfo]) -> AppInfo? {
        findEditable(in: appInfos) ?? appInfos.first
    }
}
