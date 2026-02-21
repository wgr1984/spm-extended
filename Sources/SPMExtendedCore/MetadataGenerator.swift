import Foundation

struct MetadataGenerator {
    let environment: RunEnvironment

    // MARK: - Package.json Generation

    func generatePackageJson(scratchDirectory: String, verbose: Bool, overwrite: Bool = false) throws {
        let packageJsonPath = environment.path(components: "Package.json")
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: packageJsonPath) {
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

        let result: CommandExecutor.Result
        do {
            result = try CommandExecutor.executeProcess(
                executable: environment.swiftPath,
                arguments: [
                    "package",
                    "--scratch-path", scratchDirectory,
                    "dump-package"
                ],
                workingDirectory: environment.packageDirectory,
                timeout: 30.0,
                verbose: verbose
            )
        } catch SPMExtendedError.commandFailed(let message) where message.contains("timed out") {
            try? fileManager.removeItem(atPath: scratchDirectory)
            throw SPMExtendedError.commandFailed("Package.json generation timed out after 30 seconds. This may be caused by running the plugin on its own package directory. Try running from a different package or manually create Package.json first.")
        }

        if !result.isSuccess {
            var errorMessage = "Failed to generate Package.json (exit code: \(result.exitCode))"
            if !result.errorOutput.isEmpty {
                errorMessage += "\n\nError output:\n" + result.errorOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if !result.output.isEmpty && verbose {
                errorMessage += "\n\nStandard output:\n" + result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            throw SPMExtendedError.commandFailed(errorMessage)
        }

        let output = result.output
        guard !output.isEmpty else {
            throw SPMExtendedError.commandFailed("Package.json generation produced no output")
        }

        do {
            try output.write(toFile: packageJsonPath, atomically: true, encoding: .utf8)
        } catch {
            throw SPMExtendedError.commandFailed("Failed to write Package.json: \(error.localizedDescription)")
        }

        guard fileManager.fileExists(atPath: packageJsonPath) else {
            throw SPMExtendedError.commandFailed("Package.json was not created")
        }

        if verbose {
            print("   Package.json written to: \(packageJsonPath)")
        }
    }

    // MARK: - package-metadata.json Generation

    func generatePackageMetadata(verbose: Bool, overwrite: Bool = false) throws -> String? {
        let metadataPath = environment.path(components: "package-metadata.json")

        if FileManager.default.fileExists(atPath: metadataPath) {
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

        if !overwrite {
            print("📝 Step 2: Generating package-metadata.json...")
        }

        let metadata = try extractPackageMetadata(verbose: verbose)
        try metadata.write(toFile: metadataPath, atomically: true, encoding: .utf8)

        if !overwrite {
            print("   ✓ package-metadata.json created")
            print()
        }

        if verbose {
            print("   package-metadata.json written to: \(metadataPath)")
        }

        return "package-metadata.json"
    }

    func generateMetadataIfNeeded(providedMetadataPath: String?, verbose: Bool) throws -> String? {
        if let providedPath = providedMetadataPath {
            let fullPath = providedPath.hasPrefix("/") ? providedPath : environment.path(components: providedPath)
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

        let defaultMetadataPath = environment.path(components: "package-metadata.json")
        if FileManager.default.fileExists(atPath: defaultMetadataPath) {
            if verbose {
                print("   ℹ️  Using existing package-metadata.json")
            }
            return "package-metadata.json"
        }

        return try generatePackageMetadata(verbose: verbose)
    }

    // MARK: - Metadata Extraction

    private func extractPackageMetadata(verbose: Bool) throws -> String {
        var metadataDict: [String: Any] = [:]

        if let author = extractAuthorInfo(verbose: verbose) {
            metadataDict["author"] = author
            if verbose { print("   ✓ Extracted author from git config") }
        }

        if let description = extractDescription(verbose: verbose) {
            metadataDict["description"] = description
            if verbose { print("   ✓ Extracted description from README.md") }
        }

        if let licenseInfo = extractLicenseInfo(verbose: verbose) {
            if let licenseURL = licenseInfo["licenseURL"] {
                metadataDict["licenseURL"] = licenseURL
            }
            if let licenseType = licenseInfo["licenseType"] {
                metadataDict["licenseType"] = licenseType
            }
            if verbose { print("   ✓ Extracted license information") }
        }

        if let repoURL = extractRepositoryURL(verbose: verbose) {
            metadataDict["repositoryURL"] = repoURL
            if verbose { print("   ✓ Extracted repository URL from git") }
        }

        if metadataDict.isEmpty {
            if verbose { print("   ⚠️  Could not extract metadata, using minimal defaults") }
            metadataDict = [
                "author": ["name": "Unknown"],
                "description": "A Swift package"
            ]
        }

        print()
        print("   📋 Auto-generated metadata:")
        print()
        displayMetadata(metadataDict)
        print()
        print("   ℹ️  Review metadata in package-metadata.json after generation")
        print("   💡 To customize: edit package-metadata.json and re-run with --overwrite")
        print()

        let jsonData = try JSONSerialization.data(withJSONObject: metadataDict, options: [.prettyPrinted, .sortedKeys])
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw SPMExtendedError.commandFailed("Failed to generate metadata JSON")
        }

        return jsonString
    }

    private func displayMetadata(_ metadata: [String: Any]) {
        if let author = metadata["author"] as? [String: String] {
            if let name = author["name"] { print("   • Author Name: \(name)") }
            if let email = author["email"] { print("   • Author Email: \(email)") }
        }
        if let description = metadata["description"] as? String {
            print("   • Description: \(description)")
        }
        if let licenseType = metadata["licenseType"] as? String {
            print("   • License Type: \(licenseType)")
        }
        if let licenseURL = metadata["licenseURL"] as? String {
            print("   • License URL: \(licenseURL)")
        }
        if let repoURL = metadata["repositoryURL"] as? String {
            print("   • Repository URL: \(repoURL)")
        }
    }

    private func extractAuthorInfo(verbose: Bool) -> [String: String]? {
        var author: [String: String] = [:]
        if let name = runGitCommand(args: ["config", "user.name"], verbose: verbose) {
            author["name"] = name
        }
        if let email = runGitCommand(args: ["config", "user.email"], verbose: verbose) {
            author["email"] = email
        }
        return author.isEmpty ? nil : author
    }

    private func extractDescription(verbose: Bool) -> String? {
        let readmePath = environment.path(components: "README.md")
        guard FileManager.default.fileExists(atPath: readmePath) else { return nil }

        do {
            let content = try String(contentsOfFile: readmePath, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            var foundTitle = false
            var description = ""
            var inCodeBlock = false

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("```") {
                    inCodeBlock.toggle()
                    continue
                }
                if inCodeBlock { continue }
                if trimmed.isEmpty {
                    if foundTitle && !description.isEmpty { break }
                    continue
                }
                if trimmed.hasPrefix("#") {
                    foundTitle = true
                    continue
                }
                if trimmed.hasPrefix("[![") || trimmed.hasPrefix("![") || trimmed.hasPrefix("[!") {
                    continue
                }
                if trimmed.hasPrefix("*") || trimmed.hasPrefix("-") || trimmed.hasPrefix("+") ||
                   trimmed.hasPrefix("<!--") || trimmed.range(of: "^\\d+\\.", options: .regularExpression) != nil {
                    continue
                }
                if trimmed.hasPrefix("---") || trimmed.hasPrefix("***") || trimmed.hasPrefix("___") {
                    continue
                }
                if trimmed.hasPrefix("[") || trimmed.hasPrefix("|") {
                    continue
                }
                if foundTitle {
                    if description.isEmpty {
                        description = trimmed
                    } else {
                        description += " " + trimmed
                    }
                }
            }

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
        let licenseFiles = ["LICENSE", "LICENSE.md", "LICENSE.txt", "LICENCE", "LICENCE.md"]

        for fileName in licenseFiles {
            let licensePath = environment.path(components: fileName)
            if FileManager.default.fileExists(atPath: licensePath) {
                do {
                    let licenseContent = try String(contentsOfFile: licensePath, encoding: .utf8)
                    if let type = detectLicenseType(from: licenseContent) {
                        licenseInfo["licenseType"] = type
                    }
                    if let repoURL = extractRepositoryURL(verbose: verbose) {
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

    private func detectLicenseType(from content: String) -> String? {
        let uppercased = content.uppercased()
        if uppercased.contains("MIT LICENSE") { return "MIT" }
        if uppercased.contains("APACHE LICENSE") { return "Apache-2.0" }
        if uppercased.contains("GNU GENERAL PUBLIC LICENSE") {
            if uppercased.contains("VERSION 3") { return "GPL-3.0" }
            if uppercased.contains("VERSION 2") { return "GPL-2.0" }
            return "GPL"
        }
        if uppercased.contains("BSD LICENSE") {
            if uppercased.contains("3-CLAUSE") { return "BSD-3-Clause" }
            if uppercased.contains("2-CLAUSE") { return "BSD-2-Clause" }
            return "BSD"
        }
        if uppercased.contains("MOZILLA PUBLIC LICENSE") { return "MPL-2.0" }
        return nil
    }

    private func extractRepositoryURL(verbose: Bool) -> String? {
        guard let gitURL = runGitCommand(args: ["config", "--get", "remote.origin.url"], verbose: verbose) else {
            return nil
        }
        if gitURL.hasPrefix("git@github.com:") {
            return gitURL
                .replacingOccurrences(of: "git@github.com:", with: "https://github.com/")
                .replacingOccurrences(of: ".git", with: "")
        }
        if gitURL.hasSuffix(".git") {
            return gitURL.replacingOccurrences(of: ".git", with: "")
        }
        return gitURL
    }

    private func runGitCommand(args: [String], verbose: Bool) -> String? {
        do {
            let result = try CommandExecutor.executeProcess(
                executable: "/usr/bin/git",
                arguments: args,
                workingDirectory: environment.packageDirectory,
                timeout: nil,
                verbose: false
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
