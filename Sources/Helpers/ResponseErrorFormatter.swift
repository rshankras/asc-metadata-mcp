import AppStoreConnect
import Foundation

/// Formats asc-swift `ResponseError`s into actionable messages (HTTP status +
/// App Store Connect error codes/details) instead of the opaque
/// "AppStoreConnect.ResponseError error N" that `localizedDescription` yields.
enum ResponseErrorFormatter {
    static func format(_ error: ResponseError) -> String {
        switch error {
        case .requestFailure(let errorResponse, let statusCode, _):
            var message = "HTTP \(statusCode)"
            if let errors = errorResponse?.errors {
                let details = errors.map { "\($0.code): \($0.detail)" }.joined(separator: "; ")
                message += " - \(details)"
            }
            return message
        case .rateLimitExceeded(_, let rate, _):
            return "Rate limit exceeded. Limit: \(rate?.limit ?? 0), remaining: \(rate?.remaining ?? 0)"
        case .dataAssertionFailed:
            return "No data returned from API"
        }
    }

    /// The HTTP status code if this error is a request failure, else nil.
    static func statusCode(_ error: ResponseError) -> Int? {
        if case .requestFailure(_, let statusCode, _) = error {
            return statusCode
        }
        return nil
    }
}
