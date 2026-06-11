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

    static func load() throws -> AuthConfig {
        guard FileManager.default.fileExists(atPath: configPath.path) else {
            throw AuthConfigError.configNotFound(configPath.path)
        }
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
            "Config file not found at \(path). Create it with issuerID, privateKeyID, and privateKeyPath."
        case .privateKeyNotFound(let path):
            "Private key (.p8) not found at \(path). Download it from App Store Connect."
        }
    }
}
