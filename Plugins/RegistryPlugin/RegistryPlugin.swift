import Foundation
import PackagePlugin

@main
struct RegistryPlugin: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) throws {
        let packageDirectory = context.package.directory
        let packageName = context.package.displayName
        
        // Check for subcommand
        guard let subcommand = arguments.first else {
            print("🚀 SPM Extended Plugin - Registry")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print()
            printHelp()
            return
        }
        
        // Parse subcommand
        let remainingArgs = Array(arguments.dropFirst())
        
        switch subcommand {
        case "publish":
            try handlePublish(
                context: context,
                packageDirectory: packageDirectory,
                packageName: packageName,
                arguments: remainingArgs
            )
        case "--help", "-h", "help":
            print("🚀 SPM Extended Plugin - Registry")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print()
            printHelp()
        default:
            throw PluginError.unknownSubcommand("Unknown subcommand: '\(subcommand)'. Available: publish")
        }
    }
    
    private func handlePublish(
        context: PluginContext,
        packageDirectory: Path,
        packageName: String,
        arguments: [String]
    ) throws {
        print("🚀 SPM Extended Plugin - Registry Publish")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Package: \(packageName)")
        print("Directory: \(packageDirectory)")
        print()
        
        // Parse positional arguments and options
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
                // Parse options
                switch arg {
                case "--url", "--registry-url":
                    i += 1
                    if i < arguments.count {
                        registryUrl = arguments[i]
                    }
                case "--metadata-path":
                    i += 1
                    if i < arguments.count {
                        metadataPath = arguments[i]
                    }
                case "--scratch-directory":
                    i += 1
                    if i < arguments.count {
                        scratchDirectory = arguments[i]
                    }
                case "--signing-identity":
                    i += 1
                    if i < arguments.count {
                        signingIdentity = arguments[i]
                    }
                case "--private-key-path":
                    i += 1
                    if i < arguments.count {
                        privateKeyPath = arguments[i]
                    }
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
                // Parse positional arguments
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
        
        // Validate required arguments
        guard let packageId = packageId else {
            throw PluginError.missingArgument("<package-id> is required (format: scope.name)")
        }
        
        guard let version = version else {
            throw PluginError.missingArgument("<package-version> is required")
        }
        
        // Parse package-id into scope and name
        let components = packageId.split(separator: ".")
        guard components.count == 2 else {
            throw PluginError.invalidArgument("package-id must be in format 'scope.name', got: '\(packageId)'")
        }
        
        let scope = String(components[0])
        let name = String(components[1])
        
        // Validate that the name matches the package name
        if name != packageName {
            print("⚠️  Warning: Package name '\(name)' doesn't match manifest name '\(packageName)'")
            print("   Using manifest name: '\(packageName)'")
        }
        
        // Step 1: Generate Package.json
        print("📝 Step 1: Generating Package.json...")
        try generatePackageJson(packageDirectory: packageDirectory)
        print("   ✓ Package.json created")
        print()
        
        // Step 2: Publish (unless dry-run)
        if dryRun {
            print("🔍 Dry run - Package.json generated but not published")
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
            print("🚀 Step 2: Publishing to registry...")
            print()
            
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
            
            print("   Executing: \(publishCmd)")
            print()
            
            // Execute the publish command directly
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/bash")
            task.arguments = ["-c", "cd \"\(packageDirectory.string)\" && \(publishCmd)"]
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                print("   ✓ Published successfully!")
                print()
                print("✅ Package published to registry!")
                print()
                if let url = registryUrl {
                    print("Verify in collection:")
                    print("  curl -H \"Accept: application/json\" \(url)/collection/\(scope)")
                }
            } else {
                throw PluginError.commandFailed("Publishing failed with exit code \(task.terminationStatus)")
            }
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
        var command = "swift package-registry publish \(packageId) \(version)"
        
        if let url = registryUrl {
            command += " --url \"\(url)\""
        }
        
        if let metadata = metadataPath {
            command += " --metadata-path \"\(metadata)\""
        }
        
        if let scratch = scratchDirectory {
            command += " --scratch-directory \"\(scratch)\""
        }
        
        if let identity = signingIdentity {
            command += " --signing-identity \"\(identity)\""
        }
        
        if let keyPath = privateKeyPath {
            command += " --private-key-path \"\(keyPath)\""
        }
        
        if !certChainPaths.isEmpty {
            command += " --cert-chain-paths"
            for certPath in certChainPaths {
                command += " \"\(certPath)\""
            }
        }
        
        if allowInsecureHttp {
            command += " --allow-insecure-http"
        }
        
        if verbose {
            command += " --vv"
        }
        
        return command
    }
    
    private func generatePackageJson(packageDirectory: Path) throws {
        let packageJsonPath = packageDirectory.appending(["Package.json"])
        
        // Check if Package.json already exists
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: packageJsonPath.string) {
            print("   ℹ️  Package.json already exists, using existing file")
            return
        }
        
        // Execute command directly to generate Package.json
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", "cd \"\(packageDirectory.string)\" && swift package dump-package > \"\(packageJsonPath.string)\" 2>&1"]
        
        // Capture output for debugging
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        
        try task.run()
        
        // Wait with timeout (30 seconds)
        let startTime = Date()
        let timeout: TimeInterval = 30.0
        
        while task.isRunning {
            if Date().timeIntervalSince(startTime) > timeout {
                task.terminate()
                throw PluginError.commandFailed("Package.json generation timed out after 30 seconds. This may be caused by running the plugin on its own package directory. Try running from a different package or manually create Package.json first.")
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        if task.terminationStatus != 0 {
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""
            let error = String(data: errorData, encoding: .utf8) ?? ""
            
            var errorMessage = "Failed to generate Package.json"
            if !output.isEmpty {
                errorMessage += "\nOutput: \(output)"
            }
            if !error.isEmpty {
                errorMessage += "\nError: \(error)"
            }
            
            throw PluginError.commandFailed(errorMessage)
        }
        
        // Verify it was created
        guard fileManager.fileExists(atPath: packageJsonPath.string) else {
            throw PluginError.commandFailed("Package.json was not created")
        }
    }
    
    private func printHelp() {
        print("""
        OVERVIEW: Registry operations with automatic Package.json generation
        
        USAGE: swift package registry <subcommand> [options]
        
        SUBCOMMANDS:
          publish                 Publish package to registry with Package.json generation
        
        OPTIONS:
          -h, --help              Show help information
        
        SEE ALSO:
          swift package registry publish --help
        """)
    }
    
    private func printPublishHelp() {
        print("""
        OVERVIEW: Publish to a registry with automatic Package.json generation
        
        USAGE: swift package registry publish <package-id> <package-version> [options]
        
        PERMISSION: Requires --allow-writing-to-package-directory flag or interactive approval
        
        DESCRIPTION:
          This plugin automates the publishing workflow:
          1. Generates Package.json from your Package.swift manifest
          2. Publishes to the registry (which handles archive creation)
          
          The workflow ensures packages appear in Package Collections (SE-0291).
        
        ARGUMENTS:
          <package-id>            The package identifier (format: scope.name)
          <package-version>       The package release version
        
        REGISTRY OPTIONS:
          --url <url>             Registry URL
          --metadata-path <path>  Path to package metadata JSON file
          --scratch-directory <dir>
                                  Directory for working files
          --allow-insecure-http   Allow non-HTTPS registry URLs
        
        SIGNING OPTIONS:
          --signing-identity <id> Signing identity from system store
          --private-key-path <path>
                                  Path to PKCS#8 private key (DER)
          --cert-chain-paths <paths...>
                                  Paths to signing certificates (DER)
        
        OTHER OPTIONS:
          --dry-run               Prepare only, do not publish
          --vv                    Enable verbose output
          -h, --help              Show this help message
        
        EXAMPLES:
          # Publish to registry
          swift package registry publish myorg.MyPackage 1.0.0 --url https://registry.example.com
          
          # Dry run (prepare only)
          swift package registry publish myorg.MyPackage 1.0.0 --dry-run
          
          # With metadata and signing
          swift package registry publish myorg.MyPackage 1.0.0 \\
            --url https://registry.example.com \\
            --metadata-path metadata.json \\
            --signing-identity "My Cert"
          
          # With explicit permission flag (for CI/CD)
          swift package --allow-writing-to-package-directory registry publish \\
            myorg.MyPackage 1.0.0 --url https://registry.example.com
        
        WORKFLOW:
          1. Generates Package.json
          2. Publishes to registry (which creates archive with Package.json included)
             or prepares only with --dry-run
        
        SEE ALSO:
          - SE-0291 Package Collections
          - swift package-registry publish --help
        """)
    }
}

enum PluginError: Error, CustomStringConvertible {
    case commandFailed(String)
    case missingArgument(String)
    case invalidArgument(String)
    case unknownSubcommand(String)
    
    var description: String {
        switch self {
        case .commandFailed(let message):
            return "Command failed: \(message)"
        case .missingArgument(let message):
            return "Missing required argument: \(message)"
        case .invalidArgument(let message):
            return "Invalid argument: \(message)"
        case .unknownSubcommand(let message):
            return message
        }
    }
}
