import Foundation

/// Signing info for a resource (spec 4.2.1).
struct ResourceSigningInfo {
    let signatureBase64Encoded: String?
    let signatureFormat: String?
}

/// A release resource (e.g. source-archive) from GET /{scope}/{name}/{version}.
struct ReleaseResource {
    let name: String
    let type: String
    let checksum: String?
    let signing: ResourceSigningInfo?
}

/// Release metadata from GET /{scope}/{name}/{version} (spec 4.2).
struct ReleaseMetadata {
    let id: String
    let version: String
    let resources: [ReleaseResource]
    let metadata: [String: Any]
    let publishedAt: String?
}

/// Fetches release metadata and manifest from a Swift Package Registry.
enum RegistryReleaseFetcher {
    private static let acceptJSON = "application/vnd.swift.registry.v1+json"
    private static let acceptSwift = "application/vnd.swift.registry.v1+swift"
    private static let timeout: TimeInterval = 30

    enum FetchError: Error, CustomStringConvertible {
        case invalidURL
        case releaseNotFound
        case invalidResponse(String)
        case networkError(Error)

        var description: String {
            switch self {
            case .invalidURL: return "Invalid registry URL"
            case .releaseNotFound: return "Release not found (404)"
            case .invalidResponse(let m): return "Invalid response: \(m)"
            case .networkError(let e): return "Network error: \(e.localizedDescription)"
            }
        }
    }

    static func fetchReleaseMetadata(
        registryBaseURL: String,
        scope: String,
        name: String,
        version: String
    ) async -> Result<ReleaseMetadata, FetchError> {
        let base = registryBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let path = "\(base)/\(scope)/\(name)/\(version)"
        guard let url = URL(string: path) else { return .failure(.invalidURL) }

        var request = URLRequest(url: url)
        request.setValue(Self.acceptJSON, forHTTPHeaderField: "Accept")
        request.timeoutInterval = Self.timeout

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure(.invalidResponse("Not an HTTP response"))
            }
            if http.statusCode == 404 {
                return .failure(.releaseNotFound)
            }
            guard http.statusCode == 200 else {
                return .failure(.invalidResponse("Status \(http.statusCode)"))
            }
            guard let meta = parseReleaseMetadata(data) else {
                return .failure(.invalidResponse("Invalid or missing JSON fields"))
            }
            return .success(meta)
        } catch {
            return .failure(.networkError(error))
        }
    }

    static func fetchReleaseMetadataSync(
        registryBaseURL: String,
        scope: String,
        name: String,
        version: String
    ) -> Result<ReleaseMetadata, FetchError> {
        var result: Result<ReleaseMetadata, FetchError> = .failure(.invalidResponse(""))
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            result = await fetchReleaseMetadata(
                registryBaseURL: registryBaseURL,
                scope: scope,
                name: name,
                version: version
            )
            semaphore.signal()
        }
        semaphore.wait()
        return result
    }

    private static func parseReleaseMetadata(_ data: Data) -> ReleaseMetadata? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["id"] as? String,
              let version = json["version"] as? String,
              let resourcesArray = json["resources"] as? [[String: Any]] else {
            return nil
        }
        let metadataDict = (json["metadata"] as? [String: Any]) ?? [:]
        let publishedAt = json["publishedAt"] as? String
        var resources: [ReleaseResource] = []
        for r in resourcesArray {
            let name = r["name"] as? String ?? ""
            let type = r["type"] as? String ?? ""
            let checksum = r["checksum"] as? String
            var signing: ResourceSigningInfo?
            if let s = r["signing"] as? [String: Any] {
                signing = ResourceSigningInfo(
                    signatureBase64Encoded: s["signatureBase64Encoded"] as? String,
                    signatureFormat: s["signatureFormat"] as? String
                )
            }
            resources.append(ReleaseResource(name: name, type: type, checksum: checksum, signing: signing))
        }
        return ReleaseMetadata(
            id: id,
            version: version,
            resources: resources,
            metadata: metadataDict,
            publishedAt: publishedAt
        )
    }

    static func fetchManifest(
        registryBaseURL: String,
        scope: String,
        name: String,
        version: String,
        swiftVersion: String? = nil
    ) async -> Result<(body: Data, linkHeader: String?), FetchError> {
        let base = registryBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var path = "\(base)/\(scope)/\(name)/\(version)/Package.swift"
        if let sv = swiftVersion, !sv.isEmpty {
            path += "?swift-version=\(sv)"
        }
        guard let url = URL(string: path) else { return .failure(.invalidURL) }

        var request = URLRequest(url: url)
        request.setValue(Self.acceptSwift, forHTTPHeaderField: "Accept")
        request.timeoutInterval = Self.timeout

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure(.invalidResponse("Not an HTTP response"))
            }
            if http.statusCode == 404 {
                return .failure(.releaseNotFound)
            }
            guard http.statusCode == 200 else {
                return .failure(.invalidResponse("Status \(http.statusCode)"))
            }
            let linkHeader = http.value(forHTTPHeaderField: "Link")
            return .success((body: data, linkHeader: linkHeader))
        } catch {
            return .failure(.networkError(error))
        }
    }

    static func fetchManifestSync(
        registryBaseURL: String,
        scope: String,
        name: String,
        version: String,
        swiftVersion: String? = nil
    ) -> Result<(body: Data, linkHeader: String?), FetchError> {
        var result: Result<(body: Data, linkHeader: String?), FetchError> = .failure(.invalidResponse(""))
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            result = await fetchManifest(
                registryBaseURL: registryBaseURL,
                scope: scope,
                name: name,
                version: version,
                swiftVersion: swiftVersion
            )
            semaphore.signal()
        }
        semaphore.wait()
        return result
    }
}

/// Parses Link header for alternate manifest entries (Package@swift-X.swift, swift-tools-version).
func parseManifestAlternates(from linkHeader: String?) -> [(filename: String, swiftToolsVersion: String)] {
    guard let linkHeader = linkHeader else { return [] }
    var result: [(String, String)] = []
    // Multiple links separated by comma
    let segments = linkHeader.split(separator: ",")
    for segment in segments {
        let trimmed = segment.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("<") else { continue }
        guard let endAngle = trimmed.firstIndex(of: ">") else { continue }
        let rest = trimmed[trimmed.index(after: endAngle)...]
        let parts = rest.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
        var relAlternate = false
        var filename: String?
        var swiftToolsVersion: String?
        for p in parts {
            if p == "rel=\"alternate\"" { relAlternate = true }
            else if p.hasPrefix("filename=\"") {
                let start = p.index(p.startIndex, offsetBy: 10)
                let end = p.index(before: p.endIndex)
                if p.hasSuffix("\"") { filename = String(p[start..<end]) }
            } else if p.hasPrefix("swift-tools-version=\"") {
                let start = p.index(p.startIndex, offsetBy: 21)
                let end = p.index(before: p.endIndex)
                if p.hasSuffix("\"") { swiftToolsVersion = String(p[start..<end]) }
            }
        }
        if relAlternate, let f = filename, f.contains("Package@swift-") {
            result.append((f, swiftToolsVersion ?? ""))
        }
    }
    return result
}
