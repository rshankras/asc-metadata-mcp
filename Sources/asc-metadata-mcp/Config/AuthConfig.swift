import Foundation
import AppStoreConnect

struct AuthConfig: Codable, Sendable {
    let issuerID: String
    let privateKeyID: String
    let privateKeyPath: String
    /// Default vendor number for sales/finance reports. Not retrievable via the
    /// ASC API — found in App Store Connect under Payments and Financial Reports.
    let vendorNumber: String?

    static let configDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".asc-metadata-mcp")
    static let configPath = configDirectory.appendingPathComponent("config.json")

    /// Load credentials. Environment variables take precedence over the config
    /// file so the server can run in sandboxed / CI / container contexts where
    /// secrets are injected rather than written to disk. Falls back to
    /// `~/.asc-metadata-mcp/config.json`.
    static func load() throws -> AuthConfig {
        let env = ProcessInfo.processInfo.environment
        if let issuerID = env["ASC_ISSUER_ID"],
            let privateKeyID = env["ASC_KEY_ID"],
            let privateKeyPath = env["ASC_PRIVATE_KEY_PATH"] {
            Log.info("auth: using environment variables")
            return AuthConfig(
                issuerID: issuerID,
                privateKeyID: privateKeyID,
                privateKeyPath: (privateKeyPath as NSString).expandingTildeInPath,
                vendorNumber: env["ASC_VENDOR_NUMBER"]
            )
        }

        guard FileManager.default.fileExists(atPath: configPath.path) else {
            throw AuthConfigError.configNotFound(configPath.path)
        }
        Log.info("auth: using config file \(configPath.path)")
        let data = try Data(contentsOf: configPath)
        return try JSONDecoder().decode(AuthConfig.self, from: data)
    }

    func createClient() throws -> AppStoreConnectClient {
        let keyURL = URL(filePath: privateKeyPath)
        guard FileManager.default.fileExists(atPath: privateKeyPath) else {
            throw AuthConfigError.privateKeyNotFound(privateKeyPath)
        }
        let privateKey = try JWT.PrivateKey(contentsOf: keyURL)
        return AppStoreConnectClient(
            authenticator: JWT(
                keyID: privateKeyID,
                issuerID: issuerID,
                expiryDuration: 20 * 60,
                privateKey: privateKey
            )
        )
    }
}

enum AuthConfigError: LocalizedError {
    case configNotFound(String)
    case privateKeyNotFound(String)

    var errorDescription: String? {
        switch self {
        case .configNotFound(let path):
            "No credentials found. Set the ASC_ISSUER_ID, ASC_KEY_ID, and ASC_PRIVATE_KEY_PATH environment variables (optionally ASC_VENDOR_NUMBER), or create \(path) with issuerID, privateKeyID, and privateKeyPath."
        case .privateKeyNotFound(let path):
            "Private key (.p8) not found at \(path). Download it from App Store Connect."
        }
    }
}
