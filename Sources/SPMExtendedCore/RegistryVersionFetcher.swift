import Foundation

/// Problem details for a release (RFC 7807); present when release is unavailable.
struct ReleaseProblemDetail {
    let status: Int?
    let title: String?
    let detail: String?
}

/// A single release entry from list package releases (spec 4.1).
struct ListReleaseEntry {
    let version: String
    let problem: ReleaseProblemDetail?
}

/// Fetches available version strings for a package from a Swift Package Registry.
enum RegistryVersionFetcher {
    private static let acceptHeader = "application/vnd.swift.registry.v1+json"
    private static let timeout: TimeInterval = 30

    static func fetchVersions(
        registryBaseURL: String,
        scope: String,
        name: String
    ) async -> [String] {
        let result = await fetchReleases(registryBaseURL: registryBaseURL, scope: scope, name: name)
        return result.entries.filter { $0.problem == nil }.map(\.version)
    }

    static func fetchVersionsSync(
        registryBaseURL: String,
        scope: String,
        name: String
    ) -> [String] {
        var result: [String] = []
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            result = await fetchVersions(registryBaseURL: registryBaseURL, scope: scope, name: name)
            semaphore.signal()
        }
        semaphore.wait()
        return result
    }

    /// Returns all releases with optional problem info and latest version from Link header.
    static func fetchReleases(
        registryBaseURL: String,
        scope: String,
        name: String
    ) async -> (entries: [ListReleaseEntry], latestVersion: String?) {
        let base = registryBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let path = "\(base)/\(scope)/\(name)"
        guard let url = URL(string: path) else { return ([], nil) }

        var request = URLRequest(url: url)
        request.setValue(Self.acceptHeader, forHTTPHeaderField: "Accept")
        request.timeoutInterval = Self.timeout

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return ([], nil) }
            let linkHeader = http.value(forHTTPHeaderField: "Link")
            return parseReleases(from: data, linkHeader: linkHeader)
        } catch {
            return ([], nil)
        }
    }

    static func fetchReleasesSync(
        registryBaseURL: String,
        scope: String,
        name: String
    ) -> (entries: [ListReleaseEntry], latestVersion: String?) {
        var result: ([ListReleaseEntry], String?) = ([], nil)
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            result = await fetchReleases(registryBaseURL: registryBaseURL, scope: scope, name: name)
            semaphore.signal()
        }
        semaphore.wait()
        return result
    }

    private static func parseReleases(from data: Data, linkHeader: String?) -> (entries: [ListReleaseEntry], latestVersion: String?) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let releases = json["releases"] as? [String: Any] else {
            return ([], nil)
        }
        var entries: [ListReleaseEntry] = []
        for (version, value) in releases {
            let problem: ReleaseProblemDetail?
            if let obj = value as? [String: Any], let p = obj["problem"] as? [String: Any] {
                problem = ReleaseProblemDetail(
                    status: p["status"] as? Int,
                    title: p["title"] as? String,
                    detail: p["detail"] as? String
                )
            } else {
                problem = nil
            }
            entries.append(ListReleaseEntry(version: version, problem: problem))
        }
        entries.sort { compareVersions($0.version, $1.version) == .orderedAscending }
        let latest = parseLatestVersion(from: linkHeader)
        return (entries, latest)
    }

    private static func parseLatestVersion(from linkHeader: String?) -> String? {
        guard let linkHeader = linkHeader else { return nil }
        // Link: <url>; rel="latest-version" — URL ends with /scope/name/version
        guard let regex = try? NSRegularExpression(pattern: "<([^>]+)>;\\s*rel=\"latest-version\""),
              let match = regex.firstMatch(in: linkHeader, range: NSRange(linkHeader.startIndex..<linkHeader.endIndex, in: linkHeader)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: linkHeader) else {
            return nil
        }
        let urlString = String(linkHeader[range])
        let parts = urlString.split(separator: "/", omittingEmptySubsequences: false)
        guard let last = parts.last, !last.isEmpty else { return nil }
        return String(last)
    }

    private static func compareVersions(_ a: String, _ b: String) -> ComparisonResult {
        let na = a.split(separator: ".").compactMap { Int($0) }
        let nb = b.split(separator: ".").compactMap { Int($0) }
        for (i, va) in na.enumerated() {
            let vb = i < nb.count ? nb[i] : 0
            if va < vb { return .orderedAscending }
            if va > vb { return .orderedDescending }
        }
        if nb.count > na.count { return .orderedAscending }
        return .orderedSame
    }
}
