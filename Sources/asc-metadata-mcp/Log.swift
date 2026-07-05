import Foundation

/// Lightweight logger that writes to **stderr only**.
///
/// stdout is reserved for the MCP JSON-RPC stream — writing logs there would
/// corrupt every response — so all diagnostics go to stderr, where Claude
/// Desktop / Claude Code surface them in their MCP logs.
///
/// Verbosity is controlled by the `ASC_LOG_LEVEL` environment variable
/// (`debug` | `info` | `error`); the default is `info`.
///
/// Never pass tool arguments or secrets to these methods — arguments can
/// contain app metadata, keywords, and other sensitive values.
enum Log {
    enum Level: Int, Sendable { case debug = 0, info = 1, error = 2 }

    static let threshold: Level = {
        switch ProcessInfo.processInfo.environment["ASC_LOG_LEVEL"]?.lowercased() {
        case "debug": return .debug
        case "error": return .error
        default: return .info
        }
    }()

    static func debug(_ message: @autoclosure () -> String) { emit(.debug, "DEBUG", message()) }
    static func info(_ message: @autoclosure () -> String) { emit(.info, "INFO", message()) }
    static func error(_ message: @autoclosure () -> String) { emit(.error, "ERROR", message()) }

    private static func emit(_ level: Level, _ label: String, _ message: @autoclosure () -> String) {
        guard level.rawValue >= threshold.rawValue else { return }
        let line = "[asc-metadata-mcp] \(label): \(message())\n"
        FileHandle.standardError.write(Data(line.utf8))
    }
}
