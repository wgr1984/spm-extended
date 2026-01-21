import Foundation
import PackagePlugin

struct PublishCommand {
    let context: PluginContext
    let packageDirectory: Path
    let packageName: String
    
    func execute(arguments: [String]) throws {
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
        try generatePackageJson(scratchDirectory: effectiveScratchDirectory, verbose: verbose)
        print("   ✓ Package.json created")
        print()
        
        // Step 1.5: Generate package-metadata.json if needed
        let effectiveMetadataPath = try generateMetadataIfNeeded(
            providedMetadataPath: metadataPath,
            verbose: verbose
        )
        
        // Update metadataPath with the generated one if it was created
        if effectiveMetadataPath != metadataPath {
            metadataPath = effectiveMetadataPath
            if verbose {
                print("   Using metadata file: \(effectiveMetadataPath)")
                print()
            }
        }
        
        // Step 3: Publish (unless dry-run)
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
                    print("Verify publication:")
                    print("  curl -H \"Accept: application/vnd.swift.registry.v1+json\" \(url)/\(scope)/\(packageName)")
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

        
        if verbose {
            command += " --vv"
        }
        
        return command
    }
    
    private func generatePackageJson(scratchDirectory: String, verbose: Bool) throws {
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
    
    private func generateMetadataIfNeeded(
        providedMetadataPath: String?,
        verbose: Bool
    ) throws -> String? {
        // If user provided a metadata path, check if it exists
        if let providedPath = providedMetadataPath {
            let fullPath = providedPath.hasPrefix("/") ? providedPath : packageDirectory.appending([providedPath]).string
            if FileManager.default.fileExists(atPath: fullPath) {
                if verbose {
                    print("   ℹ️  Using existing metadata file: \(providedPath)")
                }
                return providedPath
            } else {
                print("   ⚠️  Provided metadata file not found: \(providedPath)")
                print("   📝 Generating metadata automatically...")
            }
        }
        
        // Check if default package-metadata.json exists
        let defaultMetadataPath = packageDirectory.appending(["package-metadata.json"])
        if FileManager.default.fileExists(atPath: defaultMetadataPath.string) {
            if verbose {
                print("   ℹ️  Using existing package-metadata.json")
            }
            return "package-metadata.json"
        }
        
        // Generate metadata automatically
        print("📝 Step 2: Generating package-metadata.json...")
        
        let metadata = try extractPackageMetadata(verbose: verbose)
        
        // Write metadata to file
        try metadata.write(toFile: defaultMetadataPath.string, atomically: true, encoding: .utf8)
        
        print("   ✓ package-metadata.json created")
        print()
        
        return "package-metadata.json"
    }
    
    private func extractPackageMetadata(verbose: Bool) throws -> String {
        var metadataDict: [String: Any] = [:]
        
        // Extract author information from git config
        if let author = extractAuthorInfo(verbose: verbose) {
            metadataDict["author"] = author
            if verbose {
                print("   ✓ Extracted author from git config")
            }
        }
        
        // Extract description from README
        if let description = extractDescription(verbose: verbose) {
            metadataDict["description"] = description
            if verbose {
                print("   ✓ Extracted description from README.md")
            }
        }
        
        // Extract license information
        if let licenseInfo = extractLicenseInfo(verbose: verbose) {
            if let licenseURL = licenseInfo["licenseURL"] {
                metadataDict["licenseURL"] = licenseURL
            }
            if let licenseType = licenseInfo["licenseType"] {
                metadataDict["licenseType"] = licenseType
            }
            if verbose {
                print("   ✓ Extracted license information")
            }
        }
        
        // Extract repository URL from git
        if let repoURL = extractRepositoryURL(verbose: verbose) {
            metadataDict["repositoryURL"] = repoURL
            if verbose {
                print("   ✓ Extracted repository URL from git")
            }
        }
        
        // If we have no metadata at all, provide minimal defaults
        if metadataDict.isEmpty {
            if verbose {
                print("   ⚠️  Could not extract metadata, using minimal defaults")
            }
            metadataDict = [
                "author": ["name": "Unknown"],
                "description": "A Swift package"
            ]
        }
        
        // Convert to JSON
        let jsonData = try JSONSerialization.data(withJSONObject: metadataDict, options: [.prettyPrinted, .sortedKeys])
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw PluginError.commandFailed("Failed to generate metadata JSON")
        }
        
        return jsonString
    }
    
    private func extractAuthorInfo(verbose: Bool) -> [String: String]? {
        var author: [String: String] = [:]
        
        // Try to get author name from git config
        if let name = runGitCommand(args: ["config", "user.name"], verbose: verbose) {
            author["name"] = name
        }
        
        // Try to get author email from git config
        if let email = runGitCommand(args: ["config", "user.email"], verbose: verbose) {
            author["email"] = email
        }
        
        return author.isEmpty ? nil : author
    }
    
    private func extractDescription(verbose: Bool) -> String? {
        let readmePath = packageDirectory.appending(["README.md"])
        
        guard FileManager.default.fileExists(atPath: readmePath.string) else {
            return nil
        }
        
        do {
            let content = try String(contentsOfFile: readmePath.string, encoding: .utf8)
            
            // Extract first meaningful paragraph after title
            let lines = content.components(separatedBy: .newlines)
            var foundTitle = false
            var description = ""
            var inCodeBlock = false
            
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                
                // Track code blocks
                if trimmed.hasPrefix("```") {
                    inCodeBlock.toggle()
                    continue
                }
                
                // Skip lines inside code blocks
                if inCodeBlock {
                    continue
                }
                
                // Skip empty lines
                if trimmed.isEmpty {
                    if foundTitle && !description.isEmpty {
                        break // End of first paragraph
                    }
                    continue
                }
                
                // Skip title (lines starting with #)
                if trimmed.hasPrefix("#") {
                    foundTitle = true
                    continue
                }
                
                // Skip badges and images
                if trimmed.hasPrefix("[![") || trimmed.hasPrefix("![") || trimmed.hasPrefix("[!") {
                    continue
                }
                
                // Skip bullet lists (*, -, +), numbered lists, and HTML comments
                if trimmed.hasPrefix("*") || trimmed.hasPrefix("-") || trimmed.hasPrefix("+") || 
                   trimmed.hasPrefix("<!--") || trimmed.range(of: "^\\d+\\.", options: .regularExpression) != nil {
                    continue
                }
                
                // Skip horizontal rules
                if trimmed.hasPrefix("---") || trimmed.hasPrefix("***") || trimmed.hasPrefix("___") {
                    continue
                }
                
                // Skip reference-style links and tables
                if trimmed.hasPrefix("[") || trimmed.hasPrefix("|") {
                    continue
                }
                
                // Found description text
                if foundTitle {
                    if description.isEmpty {
                        description = trimmed
                    } else {
                        description += " " + trimmed
                    }
                }
            }
            
            // Clean up markdown links [text](url) -> text
            var cleaned = description
            let linkPattern = "\\[([^\\]]+)\\]\\([^\\)]+\\)"
            if let regex = try? NSRegularExpression(pattern: linkPattern, options: []) {
                cleaned = regex.stringByReplacingMatches(
                    in: cleaned,
                    options: [],
                    range: NSRange(cleaned.startIndex..., in: cleaned),
                    withTemplate: "$1"
                )
            }
            
            // Limit description length
            if cleaned.count > 300 {
                cleaned = String(cleaned.prefix(297)) + "..."
            }
            
            return cleaned.isEmpty ? nil : cleaned
        } catch {
            return nil
        }
    }
    
    private func extractLicenseInfo(verbose: Bool) -> [String: String]? {
        var licenseInfo: [String: String] = [:]
        
        // Check for LICENSE file
        let licenseFiles = ["LICENSE", "LICENSE.md", "LICENSE.txt", "LICENCE", "LICENCE.md"]
        var licenseContent: String?
        
        for fileName in licenseFiles {
            let licensePath = packageDirectory.appending([fileName])
            if FileManager.default.fileExists(atPath: licensePath.string) {
                do {
                    licenseContent = try String(contentsOfFile: licensePath.string, encoding: .utf8)
                    
                    // Try to detect license type from content
                    if let type = detectLicenseType(from: licenseContent ?? "") {
                        licenseInfo["licenseType"] = type
                    }
                    
                    // Try to get repository URL for license URL
                    if let repoURL = extractRepositoryURL(verbose: verbose) {
                        // Convert git URL to HTTPS if needed
                        var httpsURL = repoURL
                            .replacingOccurrences(of: "git@github.com:", with: "https://github.com/")
                            .replacingOccurrences(of: ".git", with: "")
                        
                        licenseInfo["licenseURL"] = "\(httpsURL)/blob/main/\(fileName)"
                    }
                    
                    break
                } catch {
                    continue
                }
            }
        }
        
        return licenseInfo.isEmpty ? nil : licenseInfo
    }
    
    private func detectLicenseType(from content: String) -> String? {
        let uppercased = content.uppercased()
        
        if uppercased.contains("MIT LICENSE") {
            return "MIT"
        } else if uppercased.contains("APACHE LICENSE") {
            return "Apache-2.0"
        } else if uppercased.contains("GNU GENERAL PUBLIC LICENSE") {
            if uppercased.contains("VERSION 3") {
                return "GPL-3.0"
            } else if uppercased.contains("VERSION 2") {
                return "GPL-2.0"
            }
            return "GPL"
        } else if uppercased.contains("BSD LICENSE") {
            if uppercased.contains("3-CLAUSE") {
                return "BSD-3-Clause"
            } else if uppercased.contains("2-CLAUSE") {
                return "BSD-2-Clause"
            }
            return "BSD"
        } else if uppercased.contains("MOZILLA PUBLIC LICENSE") {
            return "MPL-2.0"
        }
        
        return nil
    }
    
    private func extractRepositoryURL(verbose: Bool) -> String? {
        // Try to get remote URL from git
        guard let gitURL = runGitCommand(args: ["config", "--get", "remote.origin.url"], verbose: verbose) else {
            return nil
        }
        
        // Convert git@ format to https:// format for better compatibility
        if gitURL.hasPrefix("git@github.com:") {
            let httpsURL = gitURL
                .replacingOccurrences(of: "git@github.com:", with: "https://github.com/")
                .replacingOccurrences(of: ".git", with: "")
            return httpsURL
        } else if gitURL.hasSuffix(".git") {
            return gitURL.replacingOccurrences(of: ".git", with: "")
        }
        
        return gitURL
    }
    
    private func runGitCommand(args: [String], verbose: Bool) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = args
        task.currentDirectoryURL = URL(fileURLWithPath: packageDirectory.string)
        
        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = Pipe() // Suppress error output
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    return trimmed.isEmpty ? nil : trimmed
                }
            }
        } catch {
            return nil
        }
        
        return nil
    }
    
    private func printPublishHelp() {
        print("""
        OVERVIEW: Publish to a registry with automatic Package.json generation
        
        USAGE: swift package registry publish <package-id> <package-version> [options]
        
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
                                  (default: auto-generated package-metadata.json)
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
          1. Generates Package.json from manifest
          2. Auto-generates package-metadata.json (if missing)
          3. Publishes to registry (which creates archive with both files included)
             or prepares only with --dry-run
        
        NOTE:
          The plugin will automatically extract metadata from your repository.
          To override, create your own package-metadata.json or use --metadata-path.
        
        SEE ALSO:
          - SE-0291 Package Collections
          - swift package-registry publish --help
        """)
    }
}
