import Foundation

struct ListCommand {
    let environment: RunEnvironment

    /// Registry URL from --url, or from local/global registries.json (scope then default), or fallback.
    private func resolveRegistryURL(explicitURL: String?, scope: String) -> String {
        if let url = explicitURL?.trimmingCharacters(in: CharacterSet(charactersIn: "/")), !url.isEmpty {
            return url
        }
        return RegistryConfigurationReader.resolveRegistryURL(packageDirectory: environment.packageDirectory, scope: scope)
    }

    func execute(arguments: [String]) throws {
        print("\(environment.bannerPrefix()) - Registry List")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print()

        var packageId: String?
        var registryUrl: String?
        var json = false
        var includeUnavailable = false

        var positionalIndex = 0
        var i = 0
        while i < arguments.count {
            let arg = arguments[i]
            if arg.hasPrefix("--") || (arg.hasPrefix("-") && arg != "-h") {
                switch arg {
                case "--url", "--registry-url":
                    i += 1
                    if i < arguments.count { registryUrl = arguments[i] }
                case "--json":
                    json = true
                case "--include-unavailable":
                    includeUnavailable = true
                case "--help", "-h":
                    printListHelp()
                    return
                default:
                    print("⚠️  Warning: Unknown option '\(arg)'")
                }
            } else {
                if positionalIndex == 0 {
                    packageId = arg
                    positionalIndex += 1
                } else {
                    print("⚠️  Warning: Extra positional argument '\(arg)' ignored")
                }
            }
            i += 1
        }

        guard let packageId = packageId else {
            throw SPMExtendedError.missingArgument("<package-id> is required (format: scope.name)")
        }

        let components = packageId.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        guard components.count == 2, !components[0].isEmpty, !components[1].isEmpty else {
            throw SPMExtendedError.invalidArgument("package-id must be in format 'scope.name', got: '\(packageId)'")
        }
        let scope = String(components[0])
        let name = String(components[1])

        let baseURL = resolveRegistryURL(explicitURL: registryUrl, scope: scope)
        let (entries, latestVersion) = RegistryVersionFetcher.fetchReleasesSync(
            registryBaseURL: baseURL,
            scope: scope,
            name: name
        )

        let toShow = includeUnavailable ? entries : entries.filter { $0.problem == nil }
        if toShow.isEmpty {
            if entries.isEmpty {
                throw SPMExtendedError.commandFailed("No releases found for \(packageId) at \(baseURL)")
            }
            throw SPMExtendedError.commandFailed("No available releases for \(packageId) (all have problem details). Use --include-unavailable to list them.")
        }

        if json {
            printListJSON(packageId: packageId, entries: toShow, latestVersion: latestVersion)
        } else {
            printListTable(packageId: packageId, entries: toShow, latestVersion: latestVersion)
        }
    }

    private func printListTable(packageId: String, entries: [ListReleaseEntry], latestVersion: String?) {
        print("Package: \(packageId)")
        if let latest = latestVersion {
            print("Latest:  \(latest)")
        }
        print("Versions:")
        for e in entries {
            if let p = e.problem {
                let detail = p.detail ?? p.title ?? "status \(p.status ?? 0)"
                print("  \(e.version)  (unavailable: \(detail))")
            } else {
                print("  \(e.version)")
            }
        }
        print()
    }

    private func printListJSON(packageId: String, entries: [ListReleaseEntry], latestVersion: String?) {
        var obj: [String: Any] = [
            "packageId": packageId,
            "versions": entries.map { e in
                if let p = e.problem {
                    return ["version": e.version, "problem": ["status": p.status as Any, "title": p.title as Any, "detail": p.detail as Any]]
                }
                return ["version": e.version] as [String: Any]
            }
        ]
        if let latest = latestVersion { obj["latestVersion"] = latest }
        let data = try! JSONSerialization.data(withJSONObject: obj)
        if let s = String(data: data, encoding: .utf8) { print(s) }
    }

    private func printListHelp() {
        print("""
        OVERVIEW: List available versions for a package from a Swift package registry

        USAGE: swift package registry list <package-id> [options]

        DESCRIPTION:
          Fetches the list of releases for the given package (GET /{scope}/{name}).
          By default only available versions are shown; use --include-unavailable to
          include releases that have a problem (e.g. removed).

        ARGUMENTS:
          <package-id>             Package identifier in scope.name format (e.g. mona.LinkedList)

        OPTIONS:
          --url, --registry-url <url>  Registry base URL (default: from .swiftpm/configuration/registries.json or ~/.swiftpm/configuration/registries.json, else https://packages.swift.org)
          --json                       Output machine-readable JSON
          --include-unavailable        Include releases with problem details (unavailable)
          -h, --help                   Show this help message

        EXAMPLES:
          swift package --disable-sandbox registry list mona.LinkedList
          swift package --disable-sandbox registry list myorg.MyPackage --url https://registry.example.com --json
        """)
    }
}
