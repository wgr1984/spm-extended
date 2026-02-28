import Foundation

struct VerifyCommand {
    let environment: RunEnvironment

    /// Registry URL from --url, or from local/global registries.json (scope then default), or fallback.
    private func resolveRegistryURL(explicitURL: String?, scope: String) -> String {
        if let url = explicitURL?.trimmingCharacters(in: CharacterSet(charactersIn: "/")), !url.isEmpty {
            return url
        }
        return RegistryConfigurationReader.resolveRegistryURL(packageDirectory: environment.packageDirectory, scope: scope)
    }

    func execute(arguments: [String]) throws {
        print("\(environment.bannerPrefix()) - Registry Verify")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print()

        var packageId: String?
        var version: String?
        var registryUrl: String?
        var json = false
        var noManifest = false
        var verbose = false

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
                case "--no-manifest":
                    noManifest = true
                case "--verbose", "--vv":
                    verbose = true
                case "--help", "-h":
                    printVerifyHelp()
                    return
                default:
                    print("⚠️  Warning: Unknown option '\(arg)'")
                }
            } else {
                switch positionalIndex {
                case 0: packageId = arg; positionalIndex += 1
                case 1: version = arg; positionalIndex += 1
                default: print("⚠️  Warning: Extra positional argument '\(arg)' ignored")
                }
            }
            i += 1
        }

        guard let packageId = packageId else {
            throw SPMExtendedError.missingArgument("<package-id> is required (format: scope.name)")
        }
        guard let version = version else {
            throw SPMExtendedError.missingArgument("<version> is required")
        }

        let components = packageId.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        guard components.count == 2, !components[0].isEmpty, !components[1].isEmpty else {
            throw SPMExtendedError.invalidArgument("package-id must be in format 'scope.name', got: '\(packageId)'")
        }
        let scope = String(components[0])
        let name = String(components[1])

        let baseURL = resolveRegistryURL(explicitURL: registryUrl, scope: scope)

        switch RegistryReleaseFetcher.fetchReleaseMetadataSync(
            registryBaseURL: baseURL,
            scope: scope,
            name: name,
            version: version
        ) {
        case .failure(.releaseNotFound):
            throw SPMExtendedError.commandFailed("Release not found: \(packageId) \(version) at \(baseURL)")
        case .failure(let e):
            throw SPMExtendedError.commandFailed(e.description)
        case .success(let meta):
            var errors: [String] = []
            var warnings: [String] = []

            if meta.id != "\(scope).\(name)" && meta.id != packageId {
                warnings.append("Metadata id '\(meta.id)' does not match package-id '\(packageId)'")
            }
            if meta.version != version {
                warnings.append("Metadata version '\(meta.version)' does not match requested '\(version)'")
            }

            let sourceArchive = meta.resources.first { $0.name == "source-archive" && $0.type == "application/zip" }
            if sourceArchive == nil {
                errors.append("Missing source-archive resource (application/zip)")
            } else if sourceArchive?.checksum == nil || (sourceArchive?.checksum?.isEmpty ?? true) {
                warnings.append("Source-archive resource has no checksum")
            }

            let signed = sourceArchive?.signing != nil
            let signatureFormat = sourceArchive?.signing?.signatureFormat

            if meta.metadata.isEmpty && !verbose {
                warnings.append("Metadata object is empty")
            }
            if meta.publishedAt == nil || (meta.publishedAt?.isEmpty ?? true) {
                warnings.append("No publishedAt")
            }

            var manifestOk = false
            var manifestAlternates: [(filename: String, swiftToolsVersion: String)] = []
            if !noManifest {
                switch RegistryReleaseFetcher.fetchManifestSync(
                    registryBaseURL: baseURL,
                    scope: scope,
                    name: name,
                    version: version
                ) {
                case .failure(.releaseNotFound):
                    errors.append("Manifest (Package.swift) not found")
                case .failure(let e):
                    warnings.append("Manifest fetch failed: \(e.description)")
                case .success(let (_, linkHeader)):
                    manifestOk = true
                    manifestAlternates = parseManifestAlternates(from: linkHeader)
                }
            }

            if !errors.isEmpty {
                if json {
                    printVerifyJSON(
                        packageId: packageId,
                        version: version,
                        ok: false,
                        errors: errors,
                        warnings: warnings,
                        signed: signed,
                        signatureFormat: signatureFormat,
                        publishedAt: meta.publishedAt,
                        manifestFetched: !noManifest,
                        manifestOk: manifestOk,
                        manifestAlternates: manifestAlternates
                    )
                } else {
                    print("Errors:")
                    for e in errors { print("  ✗ \(e)") }
                    if !warnings.isEmpty {
                        print("Warnings:")
                        for w in warnings { print("  ⚠ \(w)") }
                    }
                }
                throw SPMExtendedError.commandFailed(errors.joined(separator: "; "))
            }

            if json {
                printVerifyJSON(
                    packageId: packageId,
                    version: version,
                    ok: true,
                    errors: [],
                    warnings: warnings,
                    signed: signed,
                    signatureFormat: signatureFormat,
                    publishedAt: meta.publishedAt,
                    manifestFetched: !noManifest,
                    manifestOk: manifestOk,
                    manifestAlternates: manifestAlternates
                )
            } else {
                print("Package:  \(meta.id)")
                print("Version:  \(meta.version)")
                print("Status:   ✓ OK")
                if signed, let fmt = signatureFormat {
                    print("Signing:  ✓ signed (\(fmt))")
                } else {
                    print("Signing:  ✗ not signed")
                }
                if let at = meta.publishedAt { print("Published: \(at)") }
                if !noManifest {
                    print("Manifest: ✓ available")
                    print("  Package.swift (default)")
                    if !manifestAlternates.isEmpty {
                        for a in manifestAlternates {
                            if a.swiftToolsVersion.isEmpty {
                                print("  \(a.filename)")
                            } else {
                                print("  \(a.filename)  swift-tools-version: \(a.swiftToolsVersion)")
                            }
                        }
                    }
                }
                if verbose && !meta.metadata.isEmpty {
                    print("Metadata:")
                    printMetadataTable(meta.metadata, indent: "  ")
                }
                if !warnings.isEmpty {
                    print("Warnings:")
                    for w in warnings { print("  ⚠ \(w)") }
                }
                print()
            }
        }
    }

    /// Prints metadata dictionary as indented key-value table (human-readable, not raw JSON).
    private func printMetadataTable(_ dict: [String: Any], indent: String) {
        let keys = dict.keys.sorted()
        for key in keys {
            guard let value = dict[key] else { continue }
            if let nested = value as? [String: Any], !nested.isEmpty {
                print("\(indent)\(key):")
                printMetadataTable(nested, indent: indent + "  ")
            } else if let arr = value as? [Any], !arr.isEmpty {
                let strings = arr.compactMap { $0 as? String }
                if strings.count == arr.count {
                    print("\(indent)\(key): \(strings.joined(separator: ", "))")
                } else {
                    print("\(indent)\(key):")
                    for (i, item) in arr.enumerated() {
                        if let sub = item as? [String: Any] {
                            print("\(indent)  [\(i)]:")
                            printMetadataTable(sub, indent: indent + "    ")
                        } else {
                            print("\(indent)  - \(item)")
                        }
                    }
                }
            } else {
                print("\(indent)\(key): \(value)")
            }
        }
    }

    private func printVerifyJSON(
        packageId: String,
        version: String,
        ok: Bool,
        errors: [String],
        warnings: [String],
        signed: Bool,
        signatureFormat: String?,
        publishedAt: String?,
        manifestFetched: Bool,
        manifestOk: Bool,
        manifestAlternates: [(filename: String, swiftToolsVersion: String)]
    ) {
        var obj: [String: Any] = [
            "packageId": packageId,
            "version": version,
            "ok": ok,
            "errors": errors,
            "warnings": warnings,
            "signed": signed,
            "manifestFetched": manifestFetched,
            "manifestOk": manifestOk
        ]
        if let fmt = signatureFormat { obj["signatureFormat"] = fmt }
        if let at = publishedAt { obj["publishedAt"] = at }
        if !manifestAlternates.isEmpty {
            obj["manifestAlternates"] = manifestAlternates.map { ["filename": $0.filename, "swiftToolsVersion": $0.swiftToolsVersion] }
        }
        let data = try! JSONSerialization.data(withJSONObject: obj)
        if let s = String(data: data, encoding: .utf8) { print(s) }
    }

    private func printVerifyHelp() {
        print("""
        OVERVIEW: Verify a package release: metadata, signing, and manifest

        USAGE: swift package registry verify <package-id> <version> [options]

        DESCRIPTION:
          Fetches release metadata (GET /{scope}/{name}/{version}) and optionally
          the package manifest (Package.swift). Reports id, version, resources,
          signing info, metadata, publishedAt, and manifest alternates (multiple
          Swift tools versions). Does not perform cryptographic signature
          verification; that is done by SwiftPM on resolution.

        ARGUMENTS:
          <package-id>   Package identifier in scope.name format
          <version>     Version to verify

        OPTIONS:
          --url, --registry-url <url>  Registry base URL (default: from .swiftpm/configuration/registries.json or ~/.swiftpm/configuration/registries.json, else https://packages.swift.org)
          --json                       Output machine-readable JSON
          --no-manifest                Skip fetching Package.swift and Link alternates
          --verbose, --vv              Include metadata dump
          -h, --help                   Show this help message

        EXAMPLES:
          swift package --disable-sandbox registry verify mona.LinkedList 1.1.1
          swift package --disable-sandbox registry verify myorg.MyPackage 1.0.0 --url https://registry.example.com --json
        """)
    }
}
