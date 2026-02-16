import Foundation
import PackagePlugin

struct OutdatedCommand {
    let context: PluginContext
    let packageDirectory: Path
    let packageName: String

    func execute(arguments: [String]) throws {
        var json = false
        var verbose = false
        var registryURLOverride: String?

        var i = 0
        while i < arguments.count {
            switch arguments[i] {
            case "--json":
                json = true
            case "--verbose", "--vv":
                verbose = true
            case "--registry-url":
                i += 1
                guard i < arguments.count else {
                    throw PluginError.commandFailed("--registry-url requires a value")
                }
                registryURLOverride = arguments[i]
            case "--help", "-h":
                printOutdatedHelp()
                return
            default:
                if arguments[i].hasPrefix("--") {
                    print("⚠️  Warning: Unknown option '\(arguments[i])'")
                }
            }
            i += 1
        }

        let resolvedPath = packageDirectory.appending("Package.resolved").string
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: resolvedPath) else {
            throw PluginError.commandFailed(
                "Package.resolved not found. Run 'swift package resolve' first."
            )
        }

        let pins: [ResolvedPin]
        do {
            pins = try ResolvedParser.parse(filePath: resolvedPath)
        } catch let e as ResolvedParserError {
            throw PluginError.commandFailed(e.description)
        } catch {
            throw PluginError.commandFailed("Failed to parse Package.resolved: \(error)")
        }

        if pins.isEmpty {
            if json {
                print("[]")
            } else {
                print("No dependencies in Package.resolved.")
            }
            return
        }

        var rows: [(identity: String, current: String?, available: [String], error: String?)] = []
        for pin in pins {
            let available: [String]
            let errorMessage: String?
            if pin.isRegistry {
                let registryBase: String
                if !pin.location.isEmpty {
                    registryBase = pin.location
                } else if let override = registryURLOverride {
                    registryBase = override.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                } else {
                    registryBase = defaultRegistryURL()
                }
                let parts = pin.identity.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
                let scope = String(parts.first ?? "")
                let name = parts.count > 1 ? String(parts[1]) : pin.identity
                if scope.isEmpty || name.isEmpty {
                    available = []
                    errorMessage = "Invalid registry identity: \(pin.identity)"
                } else {
                    available = RegistryVersionFetcher.fetchVersionsSync(
                        registryBaseURL: registryBase,
                        scope: scope,
                        name: name
                    )
                    errorMessage = available.isEmpty && !registryBase.isEmpty ? "Could not fetch versions (check registry URL and network)." : nil
                }
            } else {
                do {
                    let result = try fetchGitTagVersions(remoteURL: pin.location, verbose: verbose)
                    available = result.versions
                    errorMessage = result.error
                } catch {
                    if let pe = error as? PluginError { throw pe }
                    available = []
                    errorMessage = "\(error)"
                }
            }
            rows.append((pin.identity, pin.currentVersion, available, errorMessage))
        }

        if json {
            printJSON(rows: rows)
        } else {
            printTable(rows: rows, verbose: verbose)
        }
    }

    private func defaultRegistryURL() -> String {
        return "https://packages.swift.org"
    }

    private func fetchGitTagVersions(remoteURL: String, verbose: Bool) throws -> (versions: [String], error: String?) {
        guard let url = URL(string: remoteURL), url.scheme != nil else {
            return ([], "Invalid Git URL: \(remoteURL)")
        }
        let cmd = "git ls-remote --tags \"\(remoteURL.replacingOccurrences(of: "\"", with: "\\\""))\" 2>&1"
        let result = try CommandExecutor.execute(command: cmd, workingDirectory: packageDirectory.string)
        if !result.isSuccess {
            let err = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            if SandboxErrorHelper.isSandboxError(err) {
                throw PluginError.sandboxRequired(SandboxErrorHelper.outdatedSandboxErrorMessage())
            }
            return ([], err.isEmpty ? "Git failed" : err)
        }
        let versions = parseGitTagRefs(result.output)
        return (versions, nil)
    }

    private func parseGitTagRefs(_ output: String) -> [String] {
        let lines = output.split(separator: "\n")
        var seen = Set<String>()
        for line in lines {
            let parts = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count >= 2 else { continue }
            var ref = String(parts[1])
            if ref.hasPrefix("refs/tags/") {
                ref = String(ref.dropFirst("refs/tags/".count))
                if ref.hasSuffix("^{}") { ref = String(ref.dropLast(3)) }
                if isSemVerLike(ref) { seen.insert(ref) }
            }
        }
        return seen.sorted { a, b in compareVersions(a, b) == .orderedAscending }
    }

    private func isSemVerLike(_ s: String) -> Bool {
        let trimmed = s.trimmingCharacters(in: CharacterSet.whitespaces)
        guard !trimmed.isEmpty else { return false }
        if trimmed.hasPrefix("v") {
            return trimmed.dropFirst().allSatisfy { $0.isNumber || $0 == "." }
        }
        return trimmed.allSatisfy { $0.isNumber || $0 == "." }
    }

    private func compareVersions(_ a: String, _ b: String) -> ComparisonResult {
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

    private func printTable(rows: [(identity: String, current: String?, available: [String], error: String?)], verbose: Bool) {
        print("Dependency versions (independent of Package.swift restrictions)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        let maxId = max(8, rows.map(\.identity.count).max() ?? 8)
        let headerId = "Package".padding(toLength: maxId, withPad: " ", startingAt: 0)
        print("\(headerId)  Current    Available")
        print(String(repeating: "─", count: maxId + 2 + 10 + 2 + (verbose ? 50 : 30)))
        for row in rows {
            let current = row.current ?? "—"
            let availableStr: String
            if let err = row.error {
                availableStr = "(error: \(err))"
            } else if row.available.isEmpty {
                availableStr = "—"
            } else if verbose {
                availableStr = row.available.joined(separator: ", ")
            } else {
                availableStr = row.available.last ?? "—"
            }
            let idPad = row.identity.padding(toLength: maxId, withPad: " ", startingAt: 0)
            print("\(idPad)  \(current.padding(toLength: 8, withPad: " ", startingAt: 0))  \(availableStr)")
        }
        print()
    }

    private func printJSON(rows: [(identity: String, current: String?, available: [String], error: String?)]) {
        var arr: [[String: Any]] = []
        for row in rows {
            var obj: [String: Any] = [
                "identity": row.identity,
                "currentVersion": row.current as Any,
                "availableVersions": row.available
            ]
            if let latest = row.available.last { obj["latest"] = latest }
            if let err = row.error { obj["error"] = err }
            arr.append(obj)
        }
        let data = try! JSONSerialization.data(withJSONObject: arr)
        if let s = String(data: data, encoding: .utf8) { print(s) }
    }

    private func printOutdatedHelp() {
        print("""
        OVERVIEW: List available versions of all dependencies (ignores Package.swift version restrictions)

        USAGE: swift package --disable-sandbox outdated [options]

        DESCRIPTION:
          Reads Package.resolved and, for each dependency, fetches available versions
          from the registry or Git remote. Shows current vs available versions regardless
          of the version constraints in your Package.swift.

          Requires network access. Use --disable-sandbox.

        OPTIONS:
          --json                 Output machine-readable JSON
          --verbose, --vv        Show all available versions per package (default: latest only)
          --registry-url <url>   Use this registry for pins with no location (e.g. local registry)
          -h, --help             Show this help message

        EXAMPLE:
          swift package --disable-sandbox outdated
          swift package --disable-sandbox outdated --json
        """)
    }
}
