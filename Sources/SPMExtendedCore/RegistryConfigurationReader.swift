import Foundation

/// Reads SwiftPM registry configuration from local and global registries.json.
/// Paths match SwiftPM: .swiftpm/configuration/registries.json (local) and ~/.swiftpm/configuration/registries.json (global).
/// JSON structure: { "version": 1, "registries": { "[default]": { "url": "..." }, "scopeName": { "url": "..." } } }
enum RegistryConfigurationReader {
    private static let fallbackURL = "https://packages.swift.org"
    private static let defaultKey = "[default]"

    /// Resolves the registry URL for the given scope: scoped registry if configured, else default registry, else fallback.
    /// When scope is nil, returns default registry URL only.
    /// Checks local config first, then global, so local overrides global.
    static func resolveRegistryURL(packageDirectory: String, scope: String?) -> String {
        let fileManager = FileManager.default
        let localPath = (packageDirectory as NSString).appendingPathComponent(".swiftpm/configuration/registries.json")
        let globalPath: String = {
            let home = ProcessInfo.processInfo.environment["HOME"]
                ?? NSString(string: fileManager.homeDirectoryForCurrentUser.path).expandingTildeInPath
            return (home as NSString).appendingPathComponent(".swiftpm/configuration/registries.json")
        }()

        if let url = urlFromFile(localPath, scope: scope) { return url }
        if let url = urlFromFile(globalPath, scope: scope) { return url }
        return fallbackURL
    }

    private static func urlFromFile(_ path: String, scope: String?) -> String? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: path),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let registries = json["registries"] as? [String: Any] else {
            return nil
        }
        if let scope = scope, !scope.isEmpty, let entry = registries[scope] as? [String: Any], let url = entry["url"] as? String {
            return url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        if let defaultEntry = registries[Self.defaultKey] as? [String: Any], let url = defaultEntry["url"] as? String {
            return url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        return nil
    }
}
