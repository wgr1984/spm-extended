import Foundation

/// Fetches available version strings for a package from a Swift Package Registry.
enum RegistryVersionFetcher {
    private static let acceptHeader = "application/vnd.swift.registry.v1+json"
    private static let timeout: TimeInterval = 30

    static func fetchVersions(
        registryBaseURL: String,
        scope: String,
        name: String
    ) async -> [String] {
        let base = registryBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let path = "\(base)/\(scope)/\(name)"
        guard let url = URL(string: path) else { return [] }

        var request = URLRequest(url: url)
        request.setValue(Self.acceptHeader, forHTTPHeaderField: "Accept")
        request.timeoutInterval = Self.timeout

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }
            return parseVersions(from: data)
        } catch {
            return []
        }
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

    private static func parseVersions(from data: Data) -> [String] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let releases = json["releases"] as? [String: Any] else {
            return []
        }
        return releases.keys.sorted { (a, b) in
            compareVersions(a, b) == .orderedAscending
        }
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
