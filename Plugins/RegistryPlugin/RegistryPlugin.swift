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
        var disableSandbox = false
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
                case "--disable-sandbox":
                    disableSandbox = true
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
        
        // Validate that --disable-sandbox is provided
        guard disableSandbox else {
            throw PluginError.sandboxRequired("""
            
            ❌ The --disable-sandbox flag is required to publish packages.
            
            WHY THIS IS NEEDED:
            Swift Package Manager plugins run in a sandbox environment by default, which restricts 
            file system access and network operations. Publishing to a registry requires:
            
            • Writing Package.json to the package directory
            • Creating temporary archives and metadata files
            • Making network requests to the registry server
            • Accessing signing keys and certificates (if using signed releases)
            
            These operations are blocked by the sandbox and will cause the publish to fail.
            
            HOW TO FIX:
            Add the --disable-sandbox flag to your command:
            
              swift package --disable-sandbox registry publish \\
                myorg.MyPackage 1.0.0 --url https://registry.example.com
            
            NOTE: This flag is safe to use for publishing operations and is standard practice 
                  for registry workflows that require file system and network access.
            """)
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
                    
        // Use user-provided scratch directory, or create a temporary one
        let effectiveScratchDirectory = scratchDirectory ?? "/tmp/spm-plugin-publish-\(UUID().uuidString)"
        
        // Create the scratch directory if it doesn't exist
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: effectiveScratchDirectory) {
            try fileManager.createDirectory(atPath: effectiveScratchDirectory, withIntermediateDirectories: true, attributes: nil)
            if verbose {
                print("   Created scratch directory: \(effectiveScratchDirectory)")
            }
        }
            
        // Step 1: Generate Package.json
        print("📝 Step 1: Generating Package.json...")
        try generatePackageJson(context: context, packageDirectory: packageDirectory, scratchDirectory: effectiveScratchDirectory, verbose: verbose)
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
                disableSandbox: disableSandbox,
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
                scratchDirectory: effectiveScratchDirectory,
                signingIdentity: signingIdentity,
                privateKeyPath: privateKeyPath,
                certChainPaths: certChainPaths,
                allowInsecureHttp: allowInsecureHttp,
                disableSandbox: disableSandbox,
                verbose: verbose
            )
            
            if verbose {
                print("   Using scratch directory: \(effectiveScratchDirectory)")
            }
            print("   Executing: \(publishCmd)")
            print()
            
            // Execute the publish command directly
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/bash")
            task.arguments = ["-c", "cd \"\(packageDirectory.string)\" && \(publishCmd)"]
            try task.run()
            task.waitUntilExit()
            
            // Clean up temporary scratch directory if we created one
            if scratchDirectory == nil {
                try? FileManager.default.removeItem(atPath: effectiveScratchDirectory)
            }
            
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
        disableSandbox: Bool,
        verbose: Bool
    ) -> String {
        var command = "swift package-registry"
        
        // Add scratch-path as a global option to avoid .build directory locks
        if let scratch = scratchDirectory {
            command += " --scratch-path \"\(scratch)\""
        }
        
        command += " publish \(packageId) \(version)"
        
        if let url = registryUrl {
            command += " --url \"\(url)\""
        }
        
        if let metadata = metadataPath {
            command += " --metadata-path \"\(metadata)\""
        }
        
        // Also add scratch-directory as a subcommand option for working files
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

        if disableSandbox {
            command += " --disable-sandbox"
        }
        
        if verbose {
            command += " --vv"
        }
        
        return command
    }
    
    private func generatePackageJson(context: PluginContext, packageDirectory: Path, scratchDirectory: String, verbose: Bool) throws {
        let packageJsonPath = packageDirectory.appending(["Package.json"])
        
        // Check if Package.json already exists
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: packageJsonPath.string) {
            print("   ℹ️  Package.json already exists, using existing file")
            return
        }
        

        if verbose {
            print("   Using scratch path: \(scratchDirectory)")
        }
        
        // Get the swift tool from the plugin context to avoid sandbox issues
        let swiftTool = try context.tool(named: "swift")
        
        // Execute command with scratch path to avoid blocking
        let task = Process()
        task.executableURL = URL(fileURLWithPath: swiftTool.path.string)
        task.arguments = [
            "package",
            "--scratch-path", scratchDirectory,
            "--disable-sandbox",
            "dump-package"
        ]
        task.currentDirectoryURL = URL(fileURLWithPath: packageDirectory.string)
        
        // Capture output
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        
        if verbose {
            print("   Executing: \(swiftTool.path.string) package --scratch-path \"\(scratchDirectory)\" --disable-sandbox dump-package")
        }
        
        try task.run()
        
        // Wait with timeout (30 seconds)
        let startTime = Date()
        let timeout: TimeInterval = 30.0
        
        while task.isRunning {
            if Date().timeIntervalSince(startTime) > timeout {
                task.terminate()
                // Clean up scratch directory
                try? fileManager.removeItem(atPath: scratchDirectory)
                throw PluginError.commandFailed("Package.json generation timed out after 30 seconds. This may be caused by running the plugin on its own package directory. Try running from a different package or manually create Package.json first.")
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        // Read the output
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
        
        // Don't clean up scratch directory here - it's needed for the publish command
        // Cleanup happens at the end of handlePublish() instead
        
        if task.terminationStatus != 0 {
            var errorMessage = "Failed to generate Package.json (exit code: \(task.terminationStatus))"
            if !errorOutput.isEmpty {
                errorMessage += "\n\nError output:\n" + errorOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if !output.isEmpty && verbose {
                errorMessage += "\n\nStandard output:\n" + output.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            throw PluginError.commandFailed(errorMessage)
        }
        
        // Write the output to Package.json
        guard !output.isEmpty else {
            throw PluginError.commandFailed("Package.json generation produced no output")
        }
        
        do {
            try output.write(toFile: packageJsonPath.string, atomically: true, encoding: .utf8)
        } catch {
            throw PluginError.commandFailed("Failed to write Package.json: \(error.localizedDescription)")
        }
        
        // Verify it was created
        guard fileManager.fileExists(atPath: packageJsonPath.string) else {
            throw PluginError.commandFailed("Package.json was not created")
        }
        
        if verbose {
            print("   Package.json written to: \(packageJsonPath.string)")
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
          --allow-insecure-http   [NOT WORKING] Allow non-HTTPS registry URLs
                                  (Does not work, especially with authentication)
        
        SIGNING OPTIONS:
          --signing-identity <id> Signing identity from system store
          --private-key-path <path>
                                  Path to PKCS#8 private key (DER)
          --cert-chain-paths <paths...>
                                  Paths to signing certificates (DER)
        
        OTHER OPTIONS:
          --disable-sandbox       **REQUIRED** Disable sandbox to allow file system
                                  and network access needed for publishing
          --dry-run               Prepare only, do not publish
          --vv                    Enable verbose output
          -h, --help              Show this help message
        
        EXAMPLES:
          # Publish to registry
          swift package registry publish myorg.MyPackage 1.0.0 \\
            --url https://registry.example.com --disable-sandbox
          
          # Dry run (prepare only)
          swift package registry publish myorg.MyPackage 1.0.0 \\
            --dry-run --disable-sandbox
          
          # With metadata and signing
          swift package registry publish myorg.MyPackage 1.0.0 \\
            --url https://registry.example.com \\
            --metadata-path metadata.json \\
            --signing-identity "My Cert" \\
            --disable-sandbox
          
          # With explicit permission flag (for CI/CD)
          swift package --allow-writing-to-package-directory registry publish \\
            myorg.MyPackage 1.0.0 --url https://registry.example.com --disable-sandbox
        
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
    case sandboxRequired(String)
    
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
        case .sandboxRequired(let message):
            return message
        }
    }
}
