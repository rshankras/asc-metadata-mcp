import Foundation
import AppStoreConnect

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Works around a date-encoding bug in asc-swift's Swift ≥6.0 path
/// (`Formatters.swift/encodeISO8601Date`): the ISO-8601 format style is built
/// without a time-zone component, producing strings like
/// `2026-07-18T00:00:00.000` that the ASC API rejects with
/// `ENTITY_ERROR.ATTRIBUTE.TYPE … Expected an ISO 8601 date-time`
/// (hit via app-event `territorySchedules`, the first Date-carrying payload
/// this server sends). The format style renders in GMT, so appending `Z` is
/// exactly correct. Remove once asc-swift adds `.timeZone(separator:)` to its
/// encode style.
struct ZonedDateFixingTransport: Transport {
    let base: any Transport

    /// Matches a quoted zone-less fractional ISO-8601 date-time — the closing
    /// quote immediately after the fractional digits guarantees no `Z`/offset
    /// is already present, so already-correct strings are left untouched.
    private static let zonelessDate = #""(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{1,6})""#

    private func fixingBody(of request: URLRequest) -> URLRequest {
        guard let body = request.httpBody,
              let json = String(data: body, encoding: .utf8)
        else { return request }
        let fixed = json.replacingOccurrences(
            of: Self.zonelessDate,
            with: #""$1Z""#,
            options: .regularExpression
        )
        guard fixed != json else { return request }
        var request = request
        request.httpBody = fixed.data(using: .utf8)
        return request
    }

    func send(request: URLRequest, decoder: JSONDecoder) async throws -> Response<Data> {
        try await base.send(request: fixingBody(of: request), decoder: decoder)
    }

    func download(request: URLRequest) async throws -> Response<URL> {
        try await base.download(request: request)
    }

    func upload(request: URLRequest, data: Data, decoder: JSONDecoder) async throws -> Response<Data> {
        try await base.upload(request: fixingBody(of: request), data: data, decoder: decoder)
    }
}
