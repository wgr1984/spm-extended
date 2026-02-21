import Foundation
import PackagePlugin

struct CreateSigningCommand {
    let context: PluginContext
    let packageDirectory: Path
    let packageName: String

    private let fileManager = FileManager.default

    func execute(arguments: [String]) throws {
        print("🚀 SPM Extended Plugin - Registry Create Signing")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Package: \(packageName)")
        print("Directory: \(packageDirectory)")
        print()

        var outputDir: String?
        var applyGlobal = false
        var applyLocal = false
        var createLeafCert = false
        var overwrite = false
        var verbose = false
        // Signing verification enforcement (SwiftPM security config)
        var onUnsigned: String?
        var onUntrustedCert: String?
        var certExpiration: String?
        var certRevocation: String?

        var i = 0
        while i < arguments.count {
            let arg = arguments[i]
            switch arg {
            case "--output-dir":
                i += 1
                if i < arguments.count {
                    outputDir = arguments[i]
                }
            case "--global":
                applyGlobal = true
            case "--local":
                applyLocal = true
            case "--create-leaf-cert":
                createLeafCert = true
            case "--overwrite":
                overwrite = true
            case "--vv", "--verbose":
                verbose = true
            case "--on-unsigned":
                i += 1
                if i < arguments.count {
                    onUnsigned = arguments[i]
                }
            case "--on-untrusted-cert":
                i += 1
                if i < arguments.count {
                    onUntrustedCert = arguments[i]
                }
            case "--cert-expiration":
                i += 1
                if i < arguments.count {
                    certExpiration = arguments[i]
                }
            case "--cert-revocation":
                i += 1
                if i < arguments.count {
                    certRevocation = arguments[i]
                }
            case "--help", "-h":
                printCreateSigningHelp()
                return
            default:
                if arg.hasPrefix("--") {
                    print("⚠️  Warning: Unknown option '\(arg)'")
                }
            }
            i += 1
        }

        if let v = onUnsigned, !["error", "prompt", "warn", "silentAllow"].contains(v) {
            throw PluginError.commandFailed("--on-unsigned must be one of: error, prompt, warn, silentAllow (got: \(v))")
        }
        if let v = onUntrustedCert, !["error", "prompt", "warn", "silentAllow"].contains(v) {
            throw PluginError.commandFailed("--on-untrusted-cert must be one of: error, prompt, warn, silentAllow (got: \(v))")
        }
        if let v = certExpiration, !["enabled", "disabled"].contains(v) {
            throw PluginError.commandFailed("--cert-expiration must be one of: enabled, disabled (got: \(v))")
        }
        if let v = certRevocation, !["strict", "allowSoftFail", "disabled"].contains(v) {
            throw PluginError.commandFailed("--cert-revocation must be one of: strict, allowSoftFail, disabled (got: \(v))")
        }

        let effectiveOutputDir = outputDir ?? packageDirectory.appending(".swiftpm/signing").string
        let outDirURL = URL(fileURLWithPath: effectiveOutputDir)

        if fileManager.fileExists(atPath: effectiveOutputDir) {
            let caKeyPath = outDirURL.appendingPathComponent("ca.key").path
            if fileManager.fileExists(atPath: caKeyPath), !overwrite {
                throw PluginError.commandFailed(
                    "Signing files already exist in \(effectiveOutputDir). Use --overwrite to replace."
                )
            }
        } else {
            try fileManager.createDirectory(at: outDirURL, withIntermediateDirectories: true, attributes: nil)
            if verbose { print("   Created output directory: \(effectiveOutputDir)") }
        }

        guard let opensslPath = findOpenSSL() else {
            throw PluginError.commandFailed(
                "OpenSSL not found. Install it (e.g. brew install openssl) and ensure it is in PATH."
            )
        }
        if verbose { print("   Using OpenSSL: \(opensslPath)") }

        print("📝 Generating CA (EC P-256)...")
        try generateCA(opensslPath: opensslPath, outputDir: effectiveOutputDir, verbose: verbose)
        print("   ✓ CA key and certificate created (ca.key, ca.crt, ca.der)")
        print()

        var leafCertPath: String?
        var leafKeyDerPath: String?

        if createLeafCert {
            print("📝 Generating leaf signing certificate...")
            let (leafCrt, leafKeyDer) = try generateLeafCert(opensslPath: opensslPath, outputDir: effectiveOutputDir, verbose: verbose)
            leafCertPath = leafCrt
            leafKeyDerPath = leafKeyDer
            print("   ✓ Leaf certificate and key created (leaf.crt, leaf.der, leaf.key, leaf.key.der)")
            print()
        }

        let caPath = outDirURL.appendingPathComponent("ca.crt").path
        let caDerPath = outDirURL.appendingPathComponent("ca.der").path

        var shouldApplyGlobal = applyGlobal
        var shouldApplyLocal = applyLocal
        if !applyGlobal && !applyLocal && ProcessInfo.processInfo.environment["CI"] == nil {
            print("Add CA to registry settings so it can be trusted for verification?")
            if let line = readLine(), line.lowercased().hasPrefix("y") {
                print("  [g]lobal (~/.swiftpm)  [l]ocal (this project)  [b]oth  [n]one? ", terminator: "")
                if let choice = readLine()?.lowercased() {
                    switch choice.prefix(1) {
                    case "g": shouldApplyGlobal = true
                    case "l": shouldApplyLocal = true
                    case "b": shouldApplyGlobal = true; shouldApplyLocal = true
                    default: break
                    }
                }
            }
        }

        let hasSecurityOptions = onUnsigned != nil || onUntrustedCert != nil || certExpiration != nil || certRevocation != nil

        if shouldApplyGlobal {
            try adaptRegistrySettings(scope: "global", caPath: caPath, securityDir: swiftPMSecurityDir(global: true), verbose: verbose)
            print("   ✓ Global registry settings updated (~/.swiftpm/security)")
            if hasSecurityOptions {
                let configPath = (swiftPMConfigDir(global: true) as NSString).appendingPathComponent("registries.json")
                let trustedRootsDir = (swiftPMSecurityDir(global: true) as NSString).appendingPathComponent("trusted-root-certs")
                try applySecurityConfig(
                    configPath: configPath,
                    trustedRootsDir: trustedRootsDir,
                    caDerPath: caDerPath,
                    onUnsigned: onUnsigned,
                    onUntrustedCert: onUntrustedCert,
                    certExpiration: certExpiration,
                    certRevocation: certRevocation,
                    verbose: verbose
                )
                print("   ✓ Global registry security config updated (~/.swiftpm/configuration/registries.json)")
            }
        }
        if shouldApplyLocal {
            let localSecurity = packageDirectory.appending(".swiftpm/security").string
            try adaptRegistrySettings(scope: "local", caPath: caPath, securityDir: localSecurity, verbose: verbose)
            print("   ✓ Local registry settings updated (\(packageDirectory)/.swiftpm/security)")
            if hasSecurityOptions {
                let localConfigPath = packageDirectory.appending(".swiftpm/configuration/registries.json").string
                let localTrustedRootsDir = packageDirectory.appending(".swiftpm/security/trusted-root-certs").string
                try applySecurityConfig(
                    configPath: localConfigPath,
                    trustedRootsDir: localTrustedRootsDir,
                    caDerPath: caDerPath,
                    onUnsigned: onUnsigned,
                    onUntrustedCert: onUntrustedCert,
                    certExpiration: certExpiration,
                    certRevocation: certRevocation,
                    verbose: verbose
                )
                print("   ✓ Local registry security config updated (\(packageDirectory)/.swiftpm/configuration/registries.json)")
            }
        }

        print()
        print("✅ Package signing CA created successfully!")
        print()
        print("📁 Output directory: \(effectiveOutputDir)")
        print("   • ca.key, ca.crt (PEM), ca.der (for chain)")
        if let leaf = leafCertPath, let keyDer = leafKeyDerPath {
            let caDerRel = (effectiveOutputDir as NSString).appendingPathComponent("ca.der")
            let leafDerRel = (effectiveOutputDir as NSString).appendingPathComponent("leaf.der")
            let keyDerRel = (effectiveOutputDir as NSString).appendingPathComponent("leaf.key.der")
            print("   • leaf.key, leaf.crt (PEM), leaf.der, leaf.key.der (for publishing)")
            print()
            print("Publish with signing:")
            print("  swift package --disable-sandbox registry publish <id> <version> --url <registry-url> \\")
            print("    --cert-chain-paths \(leafDerRel) \(caDerRel) --private-key-path \(keyDerRel)")
        } else {
            print()
            print("To create a leaf cert for publishing: re-run with --create-leaf-cert")
        }
        print()
    }

    private func findOpenSSL() -> String? {
        let candidates = ["/usr/bin/openssl", "/opt/homebrew/bin/openssl", "/usr/local/bin/openssl"]
        for path in candidates where fileManager.isExecutableFile(atPath: path) {
            return path
        }
        guard let path = ProcessInfo.processInfo.environment["PATH"] else { return nil }
        for component in path.split(separator: ":") {
            let dir = String(component).trimmingCharacters(in: .whitespaces)
            let full = (dir as NSString).appendingPathComponent("openssl")
            if fileManager.isExecutableFile(atPath: full) { return full }
        }
        return nil
    }

    private func runOpenSSL(_ args: [String], workingDir: String, verbose: Bool) throws {
        let result = try CommandExecutor.executeProcess(
            executable: findOpenSSL()!,
            arguments: args,
            workingDirectory: workingDir,
            timeout: 30,
            verbose: verbose
        )
        if !result.isSuccess {
            throw PluginError.commandFailed("OpenSSL failed: \(result.errorOutput)")
        }
    }

    private func generateCA(opensslPath: String, outputDir: String, verbose: Bool) throws {
        try runOpenSSL(["ecparam", "-out", "ca.key", "-name", "prime256v1", "-genkey"], workingDir: outputDir, verbose: verbose)
        try runOpenSSL([
            "req", "-new", "-x509", "-key", "ca.key", "-out", "ca.crt", "-days", "3650",
            "-sha256", "-subj", "/CN=Swift Package Signing CA"
        ], workingDir: outputDir, verbose: verbose)
        try runOpenSSL(["x509", "-in", "ca.crt", "-outform", "DER", "-out", "ca.der"], workingDir: outputDir, verbose: verbose)
    }

    private func generateLeafCert(opensslPath: String, outputDir: String, verbose: Bool) throws -> (leafCrtPath: String, leafKeyDerPath: String) {
        try runOpenSSL(["ecparam", "-out", "leaf.key", "-name", "prime256v1", "-genkey"], workingDir: outputDir, verbose: verbose)
        try runOpenSSL([
            "req", "-new", "-key", "leaf.key", "-out", "leaf.csr",
            "-subj", "/CN=Swift Package Signing"
        ], workingDir: outputDir, verbose: verbose)
        let extFile = (outputDir as NSString).appendingPathComponent("leaf.ext")
        try """
        [ v3_codesigning ]
        extendedKeyUsage = codeSigning
        """.write(toFile: extFile, atomically: true, encoding: .utf8)
        try runOpenSSL([
            "x509", "-req", "-in", "leaf.csr", "-CA", "ca.crt", "-CAkey", "ca.key", "-CAcreateserial",
            "-sha256", "-out", "leaf.crt", "-days", "3650",
            "-extfile", "leaf.ext", "-extensions", "v3_codesigning"
        ], workingDir: outputDir, verbose: verbose)
        try? fileManager.removeItem(atPath: extFile)
        try runOpenSSL(["x509", "-in", "leaf.crt", "-outform", "DER", "-out", "leaf.der"], workingDir: outputDir, verbose: verbose)
        try runOpenSSL(["pkcs8", "-topk8", "-nocrypt", "-in", "leaf.key", "-outform", "DER", "-out", "leaf.key.der"], workingDir: outputDir, verbose: verbose)
        let leafCrtPath = (outputDir as NSString).appendingPathComponent("leaf.crt")
        let leafKeyDerPath = (outputDir as NSString).appendingPathComponent("leaf.key.der")
        return (leafCrtPath, leafKeyDerPath)
    }

    private func swiftPMSecurityDir(global: Bool) -> String {
        if global {
            let home = ProcessInfo.processInfo.environment["HOME"] ?? NSString(string: fileManager.homeDirectoryForCurrentUser.path).expandingTildeInPath
            return (home as NSString).appendingPathComponent(".swiftpm/security")
        }
        return packageDirectory.appending(".swiftpm/security").string
    }

    private func adaptRegistrySettings(scope: String, caPath: String, securityDir: String, verbose: Bool) throws {
        let configDir = (securityDir as NSString).deletingLastPathComponent
        if !fileManager.fileExists(atPath: configDir) {
            try fileManager.createDirectory(atPath: configDir, withIntermediateDirectories: true, attributes: nil)
        }
        if !fileManager.fileExists(atPath: securityDir) {
            try fileManager.createDirectory(atPath: securityDir, withIntermediateDirectories: true, attributes: nil)
        }
        let destCa = (securityDir as NSString).appendingPathComponent("package-signing-ca.crt")
        if fileManager.fileExists(atPath: destCa) {
            try fileManager.removeItem(atPath: destCa)
        }
        try fileManager.copyItem(atPath: caPath, toPath: destCa)
        if verbose { print("   Copied CA to \(destCa)") }
    }

    /// Updates registries.json security.default.signing per
    /// https://github.com/swiftlang/swift-package-manager/blob/main/Documentation/PackageRegistry/PackageRegistryUsage.md#security-configuration
    /// Works for both global (configPath in ~/.swiftpm) and local (configPath in project .swiftpm).
    private func applySecurityConfig(
        configPath: String,
        trustedRootsDir: String,
        caDerPath: String,
        onUnsigned: String?,
        onUntrustedCert: String?,
        certExpiration: String?,
        certRevocation: String?,
        verbose: Bool
    ) throws {
        let configDir = (configPath as NSString).deletingLastPathComponent

        if !fileManager.fileExists(atPath: trustedRootsDir) {
            try fileManager.createDirectory(atPath: trustedRootsDir, withIntermediateDirectories: true, attributes: nil)
        }
        let destCaDer = (trustedRootsDir as NSString).appendingPathComponent("package-signing-ca.der")
        if fileManager.fileExists(atPath: destCaDer) { try? fileManager.removeItem(atPath: destCaDer) }
        try fileManager.copyItem(atPath: caDerPath, toPath: destCaDer)
        if verbose { print("   Copied CA (DER) to \(destCaDer)") }

        var root: [String: Any]
        if fileManager.fileExists(atPath: configPath) {
            let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw PluginError.commandFailed("registries.json is not a JSON object")
            }
            root = parsed
        } else {
            root = [String: Any]()
        }
        if root["version"] == nil { root["version"] = 1 }
        var security = (root["security"] as? [String: Any]) ?? [String: Any]()
        var defaultSec = (security["default"] as? [String: Any]) ?? [String: Any]()
        var signing = (defaultSec["signing"] as? [String: Any]) ?? [String: Any]()

        if let v = onUnsigned { signing["onUnsigned"] = v }
        if let v = onUntrustedCert { signing["onUntrustedCertificate"] = v }
        signing["trustedRootCertificatesPath"] = trustedRootsDir
        if signing["includeDefaultTrustedRootCertificates"] == nil {
            signing["includeDefaultTrustedRootCertificates"] = true
        }
        var validationChecks = (signing["validationChecks"] as? [String: Any]) ?? [String: Any]()
        if let v = certExpiration { validationChecks["certificateExpiration"] = v }
        if let v = certRevocation { validationChecks["certificateRevocation"] = v }
        signing["validationChecks"] = validationChecks

        defaultSec["signing"] = signing
        security["default"] = defaultSec
        root["security"] = security

        if !fileManager.fileExists(atPath: configDir) {
            try fileManager.createDirectory(atPath: configDir, withIntermediateDirectories: true, attributes: nil)
        }
        let outData = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys, .prettyPrinted])
        try outData.write(to: URL(fileURLWithPath: configPath))
        if verbose {
            print("   Wrote security.default.signing to \(configPath)")
        }
    }

    private func swiftPMConfigDir(global: Bool) -> String {
        if global {
            let home = ProcessInfo.processInfo.environment["HOME"] ?? NSString(string: fileManager.homeDirectoryForCurrentUser.path).expandingTildeInPath
            return (home as NSString).appendingPathComponent(".swiftpm/configuration")
        }
        return packageDirectory.appending(".swiftpm/configuration").string
    }

    private func printCreateSigningHelp() {
        print("""
        OVERVIEW: Create a package-signing CA and optionally a leaf certificate

        USAGE: swift package --disable-sandbox registry create-signing [options]

        DESCRIPTION:
          Generates an EC P-256 CA (key + self-signed certificate) for Swift package signing.
          Optionally generates a leaf certificate for use with registry publish.
          Can add the CA to global or local Swift PM registry settings so it is trusted.

        OPTIONS:
          --output-dir <path>     Directory for CA and certs (default: .swiftpm/signing)
          --create-leaf-cert      Also create a leaf cert and key for publishing
          --global                Add CA to global registry settings (~/.swiftpm/security)
          --local                 Add CA to local project settings (.swiftpm/security)
          --overwrite             Replace existing CA/certs in output directory
          Signing verification (with --global or --local; writes .swiftpm/configuration/registries.json):
          --on-unsigned <policy>  Unsigned packages: error|prompt|warn|silentAllow
          --on-untrusted-cert <policy>  Untrusted cert: error|prompt|warn|silentAllow
          --cert-expiration <check>     Certificate expiry: enabled|disabled
          --cert-revocation <check>     Revocation check: strict|allowSoftFail|disabled
          --vv, --verbose         Verbose output
          -h, --help              Show this help message

        EXAMPLES:
          # Create CA only
          swift package --disable-sandbox registry create-signing

          # Create CA and leaf cert, then publish
          swift package --disable-sandbox registry create-signing --create-leaf-cert
          swift package --disable-sandbox registry publish myorg.MyPackage 1.0.0 --url https://registry.example.com \\
            --cert-chain-paths .swiftpm/signing/leaf.der .swiftpm/signing/ca.der \\
            --private-key-path .swiftpm/signing/leaf.key.der

          # Create and add CA to global trust
          swift package --disable-sandbox registry create-signing --global

          # Create CA, add to global trust, and set signing verification (warn unsigned, prompt untrusted)
          swift package --disable-sandbox registry create-signing --global --on-unsigned warn --on-untrusted-cert prompt

          # Same but for this project only (local)
          swift package --disable-sandbox registry create-signing --local --on-unsigned warn --on-untrusted-cert prompt

        SEE ALSO:
          swift package registry publish --help
        """)
    }
}
