import Foundation
import CryptoKit

struct CreateSigningCommand {
    let environment: RunEnvironment

    private let fileManager = FileManager.default

    func execute(arguments: [String]) throws {
        print("🚀 SPM Extended Plugin - Registry Create Signing")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Package: \(environment.packageName)")
        print("Directory: \(environment.packageDirectory)")
        print()

        var outputDir: String?
        var caDir: String?
        var caCN: String = "Swift Package Signing CA"
        var leafCN: String = "Swift Package Signing"
        var applyGlobal = false
        var applyLocal = false
        var createLeafCert = false
        var overwrite = false
        var verbose = false
        var validityYears: Int = 10
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
                if i < arguments.count { outputDir = arguments[i] }
            case "--ca-dir":
                i += 1
                if i < arguments.count { caDir = arguments[i] }
            case "--ca-cn":
                i += 1
                if i < arguments.count { caCN = arguments[i] }
            case "--leaf-cn":
                i += 1
                if i < arguments.count { leafCN = arguments[i] }
            case "--global":
                applyGlobal = true
            case "--local":
                applyLocal = true
            case "--create-leaf-cert":
                createLeafCert = true
            case "--overwrite":
                overwrite = true
            case "--validity-years":
                i += 1
                if i < arguments.count, let n = Int(arguments[i]), n > 0 { validityYears = n }
            case "--vv", "--verbose":
                verbose = true
            case "--on-unsigned":
                i += 1
                if i < arguments.count { onUnsigned = arguments[i] }
            case "--on-untrusted-cert":
                i += 1
                if i < arguments.count { onUntrustedCert = arguments[i] }
            case "--cert-expiration":
                i += 1
                if i < arguments.count { certExpiration = arguments[i] }
            case "--cert-revocation":
                i += 1
                if i < arguments.count { certRevocation = arguments[i] }
            case "--help", "-h":
                printCreateSigningHelp()
                return
            default:
                if arg.hasPrefix("--") { print("⚠️  Warning: Unknown option '\(arg)'") }
            }
            i += 1
        }

        if let v = onUnsigned, !["error", "prompt", "warn", "silentAllow"].contains(v) {
            throw SPMExtendedError.commandFailed("--on-unsigned must be one of: error, prompt, warn, silentAllow (got: \(v))")
        }
        if let v = onUntrustedCert, !["error", "prompt", "warn", "silentAllow"].contains(v) {
            throw SPMExtendedError.commandFailed("--on-untrusted-cert must be one of: error, prompt, warn, silentAllow (got: \(v))")
        }
        if let v = certExpiration, !["enabled", "disabled"].contains(v) {
            throw SPMExtendedError.commandFailed("--cert-expiration must be one of: enabled, disabled (got: \(v))")
        }
        if let v = certRevocation, !["strict", "allowSoftFail", "disabled"].contains(v) {
            throw SPMExtendedError.commandFailed("--cert-revocation must be one of: strict, allowSoftFail, disabled (got: \(v))")
        }
        if validityYears < 1 || validityYears > 30 {
            throw SPMExtendedError.commandFailed("--validity-years must be between 1 and 30 (got: \(validityYears))")
        }
        if caDir != nil, !createLeafCert {
            throw SPMExtendedError.commandFailed("--ca-dir requires --create-leaf-cert (leaf cert is created using the existing CA in that directory)")
        }

        let effectiveOutputDir = outputDir ?? environment.path(components: ".swiftpm", "signing")
        let outDirURL = URL(fileURLWithPath: effectiveOutputDir)

        var caPrivateKey: P256.Signing.PrivateKey?
        var caSubjectDER: [UInt8]?
        var caPath: String?
        var caDerPath: String?

        if let existingCaDir = caDir {
            print("📂 Using existing CA from \(existingCaDir)...")
            let (key, subjectDER) = try SwiftSigningCertificate.loadCA(caDir: existingCaDir)
            caPrivateKey = key
            caSubjectDER = subjectDER
            caPath = (existingCaDir as NSString).appendingPathComponent("ca.crt")
            caDerPath = (existingCaDir as NSString).appendingPathComponent("ca.der")
            if verbose { print("   Loaded ca.key and ca.der, extracted CA subject") }
            if !fileManager.fileExists(atPath: effectiveOutputDir) {
                try fileManager.createDirectory(at: outDirURL, withIntermediateDirectories: true, attributes: nil)
                if verbose { print("   Created output directory: \(effectiveOutputDir)") }
            }
            print()
        } else {
            if !fileManager.fileExists(atPath: effectiveOutputDir) {
                try fileManager.createDirectory(at: outDirURL, withIntermediateDirectories: true, attributes: nil)
                if verbose { print("   Created output directory: \(effectiveOutputDir)") }
            } else {
                let caKeyPath = outDirURL.appendingPathComponent("ca.key").path
                if fileManager.fileExists(atPath: caKeyPath), !overwrite {
                    throw SPMExtendedError.commandFailed(
                        "Signing files already exist in \(effectiveOutputDir). Use --overwrite to replace."
                    )
                }
            }
            print("📝 Generating CA (EC P-256, pure Swift, CN=\"\(caCN)\", valid \(validityYears) year\(validityYears == 1 ? "" : "s"))...")
            let (key, _) = try SwiftSigningCertificate.generateCA(outputDir: effectiveOutputDir, caCN: caCN, validityYears: validityYears, verbose: verbose)
            caPrivateKey = key
            caPath = outDirURL.appendingPathComponent("ca.crt").path
            caDerPath = outDirURL.appendingPathComponent("ca.der").path
            print("   ✓ CA key and certificate created (ca.key, ca.crt, ca.der)")
            print()
        }

        var leafCertPath: String?
        var leafKeyDerPath: String?

        if createLeafCert, let key = caPrivateKey {
            let subjectDER: [UInt8] = caSubjectDER ?? SwiftSigningCertificate.caSubjectDER(caCN: caCN)
            print("📝 Generating leaf signing certificate (CN=\"\(leafCN)\")...")
            let (leafCrt, leafKeyDer) = try SwiftSigningCertificate.generateLeafCert(
                outputDir: effectiveOutputDir,
                caPrivateKey: key,
                caSubjectDER: subjectDER,
                leafCN: leafCN,
                validityYears: validityYears,
                verbose: verbose
            )
            leafCertPath = leafCrt
            leafKeyDerPath = leafKeyDer
            print("   ✓ Leaf certificate and key created (leaf.crt, leaf.der, leaf.key, leaf.key.der)")
            print()
        }

        guard let effectiveCaPath = caPath, let effectiveCaDerPath = caDerPath else {
            throw SPMExtendedError.commandFailed("Internal error: CA paths not set")
        }

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
            try adaptRegistrySettings(scope: "global", caPath: effectiveCaPath, securityDir: swiftPMSecurityDir(global: true), verbose: verbose)
            print("   ✓ Global registry settings updated (~/.swiftpm/security)")
            if hasSecurityOptions {
                let configPath = (swiftPMConfigDir(global: true) as NSString).appendingPathComponent("registries.json")
                let trustedRootsDir = (swiftPMSecurityDir(global: true) as NSString).appendingPathComponent("trusted-root-certs")
                try applySecurityConfig(
                    configPath: configPath,
                    trustedRootsDir: trustedRootsDir,
                    caDerPath: effectiveCaDerPath,
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
            let localSecurity = environment.path(components: ".swiftpm", "security")
            try adaptRegistrySettings(scope: "local", caPath: effectiveCaPath, securityDir: localSecurity, verbose: verbose)
            print("   ✓ Local registry settings updated (\(environment.packageDirectory)/.swiftpm/security)")
            if hasSecurityOptions {
                let localConfigPath = environment.path(components: ".swiftpm", "configuration", "registries.json")
                let localTrustedRootsDir = environment.path(components: ".swiftpm", "security", "trusted-root-certs")
                try applySecurityConfig(
                    configPath: localConfigPath,
                    trustedRootsDir: localTrustedRootsDir,
                    caDerPath: effectiveCaDerPath,
                    onUnsigned: onUnsigned,
                    onUntrustedCert: onUntrustedCert,
                    certExpiration: certExpiration,
                    certRevocation: certRevocation,
                    verbose: verbose
                )
                print("   ✓ Local registry security config updated (\(environment.packageDirectory)/.swiftpm/configuration/registries.json)")
            }
        }

        print()
        print(caDir != nil ? "✅ Leaf certificate created successfully!" : "✅ Package signing CA created successfully!")
        print()
        print("📁 Output directory: \(effectiveOutputDir)")
        if caDir == nil { print("   • ca.key, ca.crt (PEM), ca.der (for chain)") }
        if leafCertPath != nil, leafKeyDerPath != nil {
            let caDerRel = (effectiveOutputDir as NSString).appendingPathComponent("ca.der")
            let leafDerRel = (effectiveOutputDir as NSString).appendingPathComponent("leaf.der")
            let keyDerRel = (effectiveOutputDir as NSString).appendingPathComponent("leaf.key.der")
            print("   • leaf.key, leaf.crt (PEM), leaf.der, leaf.key.der (for publishing)")
            print()
            print("Publish with signing:")
            print("  swift package --disable-sandbox registry publish <id> <version> --url <registry-url> \\")
            print("    --cert-chain-paths \(leafDerRel) \(caDerRel) --private-key-path \(keyDerRel)")
        } else if caDir == nil {
            print()
            print("To create a leaf cert: re-run with --create-leaf-cert, or use --ca-dir <path> with --create-leaf-cert to sign with an existing CA")
        }
        print()
    }

    private func swiftPMSecurityDir(global: Bool) -> String {
        if global {
            let home = ProcessInfo.processInfo.environment["HOME"] ?? NSString(string: fileManager.homeDirectoryForCurrentUser.path).expandingTildeInPath
            return (home as NSString).appendingPathComponent(".swiftpm/security")
        }
        return environment.path(components: ".swiftpm", "security")
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
                throw SPMExtendedError.commandFailed("registries.json is not a JSON object")
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
        if verbose { print("   Wrote security.default.signing to \(configPath)") }
    }

    private func swiftPMConfigDir(global: Bool) -> String {
        if global {
            let home = ProcessInfo.processInfo.environment["HOME"] ?? NSString(string: fileManager.homeDirectoryForCurrentUser.path).expandingTildeInPath
            return (home as NSString).appendingPathComponent(".swiftpm/configuration")
        }
        return environment.path(components: ".swiftpm", "configuration")
    }

    private func printCreateSigningHelp() {
        print("""
        OVERVIEW: Create a package-signing CA and optionally a leaf certificate

        USAGE: swift package --disable-sandbox registry create-signing [options]

        OPTIONS:
          --output-dir <path>     Directory for generated files (default: .swiftpm/signing)
          --ca-dir <path>         Use existing CA from path; requires --create-leaf-cert
          --ca-cn <name>          Common name for CA subject
          --leaf-cn <name>        Common name for leaf cert subject
          --create-leaf-cert      Create leaf cert and key for publishing
          --validity-years <n>    CA and leaf cert validity in years (default: 10, range: 1–30)
          --global                Add CA to global registry settings (~/.swiftpm/security)
          --local                 Add CA to local project settings (.swiftpm/security)
          --overwrite             Replace existing CA/certs in output directory
          --on-unsigned <policy>  Unsigned packages: error|prompt|warn|silentAllow
          --on-untrusted-cert <policy>  Untrusted cert: error|prompt|warn|silentAllow
          --cert-expiration <check>     Certificate expiry: enabled|disabled
          --cert-revocation <check>     Revocation check: strict|allowSoftFail|disabled
          --vv, --verbose         Verbose output
          -h, --help              Show this help message

        EXAMPLES:
          swift package --disable-sandbox registry create-signing
          swift package --disable-sandbox registry create-signing --create-leaf-cert
          swift package --disable-sandbox registry create-signing --global
        """)
    }
}
