import Foundation

struct PublishCommand {
    let environment: RunEnvironment

    private var metadataGenerator: MetadataGenerator {
        MetadataGenerator(environment: environment)
    }

    func execute(arguments: [String]) throws {
        print("🚀 SPM Extended Plugin - Registry Publish")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Package: \(environment.packageName)")
        print("Directory: \(environment.packageDirectory)")
        print()

        var packageId: String?
        var version: String?
        var registryUrl: String?
        var metadataPath: String?
        var scratchDirectory: String?
        var signingIdentity: String?
        var privateKeyPath: String?
        var certChainPaths: [String] = []
        var allowInsecureHttp = false
        var dryRun = false
        var verbose = false

        var positionalIndex = 0
        var i = 0

        while i < arguments.count {
            let arg = arguments[i]

            if arg.hasPrefix("--") || arg.hasPrefix("-") {
                switch arg {
                case "--url", "--registry-url":
                    i += 1
                    if i < arguments.count { registryUrl = arguments[i] }
                case "--metadata-path":
                    i += 1
                    if i < arguments.count { metadataPath = arguments[i] }
                case "--scratch-directory":
                    i += 1
                    if i < arguments.count { scratchDirectory = arguments[i] }
                case "--signing-identity":
                    i += 1
                    if i < arguments.count { signingIdentity = arguments[i] }
                case "--private-key-path":
                    i += 1
                    if i < arguments.count { privateKeyPath = arguments[i] }
                case "--cert-chain-paths":
                    i += 1
                    while i < arguments.count && !arguments[i].hasPrefix("--") {
                        certChainPaths.append(arguments[i])
                        i += 1
                    }
                    i -= 1
                case "--allow-insecure-http":
                    allowInsecureHttp = true
                case "--dry-run":
                    dryRun = true
                case "--vv":
                    verbose = true
                case "--help", "-h":
                    printPublishHelp()
                    return
                default:
                    print("⚠️  Warning: Unknown option '\(arg)'")
                }
            } else {
                switch positionalIndex {
                case 0:
                    packageId = arg
                    positionalIndex += 1
                case 1:
                    version = arg
                    positionalIndex += 1
                default:
                    print("⚠️  Warning: Extra positional argument '\(arg)' ignored")
                }
            }
            i += 1
        }

        guard let packageId = packageId else {
            throw SPMExtendedError.missingArgument("<package-id> is required (format: scope.name)")
        }
        guard let version = version else {
            throw SPMExtendedError.missingArgument("<package-version> is required")
        }

        let components = packageId.split(separator: ".")
        guard components.count == 2 else {
            throw SPMExtendedError.invalidArgument("package-id must be in format 'scope.name', got: '\(packageId)'")
        }

        let scope = String(components[0])
        let name = String(components[1])

        if name != environment.packageName {
            print("⚠️  Warning: Package name '\(name)' doesn't match manifest name '\(environment.packageName)'")
            print("   Using manifest name: '\(environment.packageName)'")
        }

        do {
            let effectiveScratchDirectory = scratchDirectory ?? "/tmp/spm-plugin-publish-\(UUID().uuidString)"
            let fileManager = FileManager.default

            if !fileManager.fileExists(atPath: effectiveScratchDirectory) {
                try fileManager.createDirectory(atPath: effectiveScratchDirectory, withIntermediateDirectories: true, attributes: nil)
                if verbose { print("   Created scratch directory: \(effectiveScratchDirectory)") }
            }

            print("📝 Step 1: Generating Package.json...")
            try metadataGenerator.generatePackageJson(scratchDirectory: effectiveScratchDirectory, verbose: verbose)
            print("   ✓ Package.json created")
            print()

            let effectiveMetadataPath = try metadataGenerator.generateMetadataIfNeeded(
                providedMetadataPath: metadataPath,
                verbose: verbose
            )
            if effectiveMetadataPath != metadataPath {
                metadataPath = effectiveMetadataPath
                if verbose {
                    print("   Using metadata file: \(effectiveMetadataPath ?? "none")")
                    print()
                }
            }

            if dryRun {
                print("🔍 Dry run - Files generated but not published")
                print()
                print("To publish, run:")
                let publishCmd = buildPublishCommand(
                    packageId: packageId,
                    version: version,
                    registryUrl: registryUrl,
                    metadataPath: metadataPath,
                    scratchDirectory: scratchDirectory,
                    signingIdentity: signingIdentity,
                    privateKeyPath: privateKeyPath,
                    certChainPaths: certChainPaths,
                    allowInsecureHttp: allowInsecureHttp,
                    verbose: verbose
                )
                print("  \(publishCmd)")
            } else {
                print("🚀 Step 3: Publishing to registry...")
                print()

                let publishCmd = buildPublishCommand(
                    packageId: packageId,
                    version: version,
                    registryUrl: registryUrl,
                    metadataPath: metadataPath,
                    scratchDirectory: effectiveScratchDirectory,
                    signingIdentity: signingIdentity,
                    privateKeyPath: privateKeyPath,
                    certChainPaths: certChainPaths,
                    allowInsecureHttp: allowInsecureHttp,
                    verbose: verbose
                )

                if verbose { print("   Using scratch directory: \(effectiveScratchDirectory)") }
                print("   Executing: \(publishCmd)")
                print()

                let result = try CommandExecutor.execute(
                    command: publishCmd,
                    workingDirectory: environment.packageDirectory
                )

                if result.isSuccess {
                    if scratchDirectory == nil {
                        try? FileManager.default.removeItem(atPath: effectiveScratchDirectory)
                    }
                    print()
                    print("   ✓ Published successfully!")
                    print()
                    print("✅ Package published to registry!")
                    print()
                    if let url = registryUrl {
                        print("Verify publication:")
                        print("  curl -H \"Accept: application/vnd.swift.registry.v1+json\" \(url)/\(scope)/\(environment.packageName)")
                    }
                } else {
                    let fullOutput = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
                    print()
                    if SandboxErrorHelper.isSandboxError(fullOutput) {
                        throw SPMExtendedError.sandboxRequired(
                            SandboxErrorHelper.publishSandboxErrorMessage(
                                packageId: packageId,
                                version: version
                            )
                        )
                    }
                    throw SPMExtendedError.commandFailed("Publishing failed with exit code \(result.exitCode)")
                }
            }
        } catch let error as SPMExtendedError {
            throw error
        } catch {
            let errorDescription = String(describing: error)
            if SandboxErrorHelper.isSandboxError(errorDescription) {
                print("Original error: \(error)")
                print()
                throw SPMExtendedError.sandboxRequired(
                    SandboxErrorHelper.publishSandboxErrorMessage(
                        packageId: packageId,
                        version: version
                    )
                )
            }
            throw error
        }
    }

    private func buildPublishCommand(
        packageId: String,
        version: String,
        registryUrl: String?,
        metadataPath: String?,
        scratchDirectory: String?,
        signingIdentity: String?,
        privateKeyPath: String?,
        certChainPaths: [String],
        allowInsecureHttp: Bool,
        verbose: Bool
    ) -> String {
        var command = "swift package-registry"
        if let scratch = scratchDirectory {
            command += " --scratch-path \"\(scratch)\""
        }
        command += " publish \(packageId) \(version)"
        if let url = registryUrl { command += " --url \"\(url)\"" }
        if let metadata = metadataPath { command += " --metadata-path \"\(metadata)\"" }
        if let scratch = scratchDirectory { command += " --scratch-directory \"\(scratch)\"" }
        if let identity = signingIdentity { command += " --signing-identity \"\(identity)\"" }
        if let keyPath = privateKeyPath { command += " --private-key-path \"\(keyPath)\"" }
        if !certChainPaths.isEmpty {
            command += " --cert-chain-paths"
            for certPath in certChainPaths { command += " \"\(certPath)\"" }
        }
        if allowInsecureHttp { command += " --allow-insecure-http" }
        if verbose { command += " --vv" }
        return command
    }

    private func printPublishHelp() {
        print("""
        OVERVIEW: Publish to a registry with automatic Package.json generation

        USAGE: swift package --disable-sandbox registry publish <package-id> <package-version> [options]

        DESCRIPTION:
          This plugin automates the publishing workflow:
          1. Generates Package.json from your Package.swift manifest
          2. Auto-generates package-metadata.json (if not present) from:
             - Git config (author name/email)
             - README.md (description)
             - LICENSE file (license type/URL)
             - Git remote (repository URL)
          3. Publishes to the registry (which handles archive creation)

          The workflow ensures packages appear in Package Collections (SE-0291).

        ARGUMENTS:
          <package-id>            The package identifier (format: scope.name)
          <package-version>       The package release version

        REGISTRY OPTIONS:
          --url <url>             Registry URL
          --metadata-path <path>  Path to package metadata JSON file
          --scratch-directory <dir> Directory for working files
          --allow-insecure-http   [NOT WORKING] Allow non-HTTPS registry URLs

        SIGNING OPTIONS:
          --signing-identity <id> Signing identity from system store
          --private-key-path <path> Path to PKCS#8 private key (DER)
          --cert-chain-paths <paths...> Paths to signing certificates (DER)

        OTHER OPTIONS:
          --dry-run               Prepare only, do not publish
          --vv                    Enable verbose output
          -h, --help              Show this help message

        IMPORTANT:
          The --disable-sandbox flag must be passed to Swift Package Manager:

            swift package --disable-sandbox registry publish <package-id> <version> --url <url>

        EXAMPLES:
          swift package --disable-sandbox registry publish myorg.MyPackage 1.0.0 --url https://registry.example.com
          swift package --disable-sandbox registry publish myorg.MyPackage 1.0.0 --dry-run
        """)
    }
}
