import Foundation
import PackagePlugin

struct MetadataGenerator {
    let context: PluginContext
    let packageDirectory: Path
    let packageName: String
    
    // MARK: - Package.json Generation
    
    /// Generate the Package.json file
    /// - Parameters:
    ///   - scratchDirectory: The path to the scratch directory
    ///   - verbose: Whether to print verbose output
    ///   - overwrite: Whether to overwrite the existing file
    /// - Throws: An error if the Package.json file cannot be generated
    func generatePackageJson(scratchDirectory: String, verbose: Bool, overwrite: Bool = false) throws {
        let packageJsonPath = packageDirectory.appending(["Package.json"])
        
        // Check if Package.json already exists
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: packageJsonPath.string) {
            if overwrite {
                if verbose {
                    print("   ℹ️  Package.json already exists, overwriting...")
                }
            } else {
                print("   ℹ️  Package.json already exists, using existing file")
                return
            }
        }
        
        if verbose {
            print("   Using scratch path: \(scratchDirectory)")
        }
        
        // Get the swift tool from the plugin context to avoid sandbox issues
        let swiftTool = try context.tool(named: "swift")
        
        // Execute command with scratch path using CommandExecutor
        let result: CommandExecutor.Result
        do {
            result = try CommandExecutor.executeProcess(
                executable: swiftTool.path.string,
                arguments: [
                    "package",
                    "--scratch-path", scratchDirectory,
                    "dump-package"
                ],
                workingDirectory: packageDirectory.string,
                timeout: 30.0,
                verbose: verbose
            )
        } catch PluginError.commandFailed(let message) where message.contains("timed out") {
            // Clean up scratch directory on timeout
            try? fileManager.removeItem(atPath: scratchDirectory)
            throw PluginError.commandFailed("Package.json generation timed out after 30 seconds. This may be caused by running the plugin on its own package directory. Try running from a different package or manually create Package.json first.")
        }
        
        if !result.isSuccess {
            var errorMessage = "Failed to generate Package.json (exit code: \(result.exitCode))"
            if !result.errorOutput.isEmpty {
                errorMessage += "\n\nError output:\n" + result.errorOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if !result.output.isEmpty && verbose {
                errorMessage += "\n\nStandard output:\n" + result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            throw PluginError.commandFailed(errorMessage)
        }
        
        let output = result.output
        
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
    
    // MARK: - package-metadata.json Generation
    
    /// Generate the package-metadata.json file
    /// - Parameters:
    ///   - verbose: Whether to print verbose output
    ///   - overwrite: Whether to overwrite the existing file
    /// - Returns: The path to the metadata file, or nil if it cannot be generated
    func generatePackageMetadata(verbose: Bool, overwrite: Bool = false) throws -> String? {
        let metadataPath = packageDirectory.appending(["package-metadata.json"])
        
        // Check if package-metadata.json already exists
        if FileManager.default.fileExists(atPath: metadataPath.string) {
            if overwrite {
                if verbose {
                    print("   ℹ️  package-metadata.json already exists, overwriting...")
                }
            } else {
                if verbose {
                    print("   ℹ️  Using existing package-metadata.json")
                }
                return "package-metadata.json"
            }
        }
        
        // Generate metadata automatically
        if !overwrite {
            print("📝 Step 2: Generating package-metadata.json...")
        }
        
        let metadata = try extractPackageMetadata(verbose: verbose)
        
        // Write metadata to file
        try metadata.write(toFile: metadataPath.string, atomically: true, encoding: .utf8)
        
        if !overwrite {
            print("   ✓ package-metadata.json created")
            print()
        }
        
        if verbose {
            print("   package-metadata.json written to: \(metadataPath.string)")
        }
        
        return "package-metadata.json"
    }
    
    /// Generate metadata if needed
    /// - Parameters:
    ///   - providedMetadataPath: The path to the provided metadata file
    ///   - verbose: Whether to print verbose output
    /// - Returns: The path to the metadata file, or nil if it cannot be generated
    func generateMetadataIfNeeded(providedMetadataPath: String?, verbose: Bool) throws -> String? {
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
        return try generatePackageMetadata(verbose: verbose)
    }
    
    // MARK: - Metadata Extraction
    
    /// Extract the package metadata from the package directory
    /// - Parameters:
    ///   - verbose: Whether to print verbose output
    /// - Returns: The package metadata, or nil if it cannot be extracted
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
        
        // Show the metadata that will be used
        print()
        print("   📋 Auto-generated metadata:")
        print()
        displayMetadata(metadataDict)
        print()
        print("   ℹ️  Review metadata in package-metadata.json after generation")
        print("   💡 To customize: edit package-metadata.json and re-run with --overwrite")
        print()
        
        // Convert to JSON
        let jsonData = try JSONSerialization.data(withJSONObject: metadataDict, options: [.prettyPrinted, .sortedKeys])
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw PluginError.commandFailed("Failed to generate metadata JSON")
        }
        
        return jsonString
    }
    
    /// Display the metadata in a readable format
    /// - Parameters:
    ///   - metadata: The metadata to display
    private func displayMetadata(_ metadata: [String: Any]) {
        // Display author
        if let author = metadata["author"] as? [String: String] {
            if let name = author["name"] {
                print("   • Author Name: \(name)")
            }
            if let email = author["email"] {
                print("   • Author Email: \(email)")
            }
        }
        
        // Display description
        if let description = metadata["description"] as? String {
            print("   • Description: \(description)")
        }
        
        // Display license info
        if let licenseType = metadata["licenseType"] as? String {
            print("   • License Type: \(licenseType)")
        }
        if let licenseURL = metadata["licenseURL"] as? String {
            print("   • License URL: \(licenseURL)")
        }
        
        // Display repository URL
        if let repoURL = metadata["repositoryURL"] as? String {
            print("   • Repository URL: \(repoURL)")
        }
    }
    
    // MARK: - Private Extraction Helpers
    
    /// Extract the author information from git config
    /// - Parameters:
    ///   - verbose: Whether to print verbose output
    /// - Returns: The author information, or nil if it cannot be extracted
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
    
    /// Extract the description from the README.md file
    /// - Parameters:
    ///   - verbose: Whether to print verbose output
    /// - Returns: The description, or nil if it cannot be extracted
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
    
    /// Extract the license information from the license file
    /// - Parameters:
    ///   - verbose: Whether to print verbose output
    /// - Returns: The license information, or nil if it cannot be extracted
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
                        let httpsURL = repoURL
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
    
    /// Detect the license type from the license content
    /// - Parameters:
    ///   - from: The license content
    /// - Returns: The license type, or nil if it cannot be detected
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
    
    /// Extract the repository URL from git
    /// - Parameters:
    ///   - verbose: Whether to print verbose output
    /// - Returns: The repository URL, or nil if it cannot be extracted
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
    
    /// Run a git command with real-time output streaming and capture
    /// - Parameters:
    ///   - args: The arguments to pass to the git command
    ///   - verbose: Whether to print verbose output
    /// - Returns: The output of the git command, or nil if the command failed
    /// - Throws: Error if the process cannot be started
    private func runGitCommand(args: [String], verbose: Bool) -> String? {
        do {
            let result = try CommandExecutor.executeProcess(
                executable: "/usr/bin/git",
                arguments: args,
                workingDirectory: packageDirectory.string,
                timeout: nil, // Git commands should be fast, no timeout needed
                verbose: false // Suppress verbose output for git commands
            )
            
            if result.isSuccess {
                let trimmed = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
        } catch {
            return nil
        }
        
        return nil
    }
}
