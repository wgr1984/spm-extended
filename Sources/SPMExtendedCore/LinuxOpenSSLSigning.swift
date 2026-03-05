#if !canImport(CryptoKit)
import Foundation

/// On Linux, create-signing uses the system `openssl` CLI (no Swift crypto dependency).
enum LinuxOpenSSLSigning {

    static func run(
        outputDir: String,
        caDir: String?,
        caCN: String,
        leafCN: String,
        createLeafCert: Bool,
        validityYears: Int,
        overwrite: Bool,
        verbose: Bool,
        fileManager: FileManager
    ) throws -> (caPath: String, caDerPath: String, leafCertPath: String?, leafKeyDerPath: String?) {
        let days = validityYears * 365
        let caKeyPath = (outputDir as NSString).appendingPathComponent("ca.key")
        let caCrtPath = (outputDir as NSString).appendingPathComponent("ca.crt")
        let caDerPath = (outputDir as NSString).appendingPathComponent("ca.der")

        if let existingCa = caDir {
            guard fileManager.fileExists(atPath: (existingCa as NSString).appendingPathComponent("ca.key")),
                  fileManager.fileExists(atPath: (existingCa as NSString).appendingPathComponent("ca.der")) else {
                throw SPMExtendedError.commandFailed("ca.key and ca.der must exist in \(existingCa)")
            }
            if !fileManager.fileExists(atPath: outputDir) {
                try fileManager.createDirectory(at: URL(fileURLWithPath: outputDir), withIntermediateDirectories: true, attributes: nil)
            }
            let existingCaCrt = (existingCa as NSString).appendingPathComponent("ca.crt")
            if !fileManager.fileExists(atPath: existingCaCrt) {
                try runOpenSSL(["x509", "-in", (existingCa as NSString).appendingPathComponent("ca.der"), "-inform", "DER", "-out", existingCaCrt])
            }
            if createLeafCert {
                let leafCrtPath = (outputDir as NSString).appendingPathComponent("leaf.crt")
                let leafDerPath = (outputDir as NSString).appendingPathComponent("leaf.der")
                let leafKeyPath = (outputDir as NSString).appendingPathComponent("leaf.key")
                let leafKeyDerPath = (outputDir as NSString).appendingPathComponent("leaf.key.der")
                try generateLeafWithOpenSSL(
                    caKeyPath: (existingCa as NSString).appendingPathComponent("ca.key"),
                    caDerPath: (existingCa as NSString).appendingPathComponent("ca.der"),
                    leafCN: leafCN,
                    days: days,
                    leafKeyPath: leafKeyPath,
                    leafCrtPath: leafCrtPath,
                    leafDerPath: leafDerPath,
                    leafKeyDerPath: leafKeyDerPath,
                    verbose: verbose
                )
                return (caCrtPath, (existingCa as NSString).appendingPathComponent("ca.der"), leafCrtPath, leafKeyDerPath)
            }
            return (existingCaCrt, (existingCa as NSString).appendingPathComponent("ca.der"), nil, nil)
        }

        if fileManager.fileExists(atPath: caKeyPath), !overwrite {
            throw SPMExtendedError.commandFailed("Signing files already exist in \(outputDir). Use --overwrite to replace.")
        }

        let subjectCA = escapeOpenSSLSubject(caCN)
        try runOpenSSL([
            "req", "-new", "-x509", "-nodes", "-newkey", "ec", "-pkeyopt", "ec_paramgen_curve:P-256",
            "-keyout", caKeyPath, "-out", caDerPath, "-outform", "DER",
            "-days", "\(days)", "-subj", "/CN=\(subjectCA)",
            "-addext", "basicConstraints=critical,CA:true"
        ])
        try runOpenSSL(["x509", "-in", caDerPath, "-inform", "DER", "-out", caCrtPath])
        if verbose { print("   Wrote \(caKeyPath), \(caCrtPath), \(caDerPath)") }

        var leafCrtPath: String?
        var leafKeyDerPath: String?

        if createLeafCert {
            let leafKeyPath = (outputDir as NSString).appendingPathComponent("leaf.key")
            let leafCrt = (outputDir as NSString).appendingPathComponent("leaf.crt")
            let leafDerPath = (outputDir as NSString).appendingPathComponent("leaf.der")
            let leafKeyDer = (outputDir as NSString).appendingPathComponent("leaf.key.der")
            try generateLeafWithOpenSSL(
                caKeyPath: caKeyPath,
                caDerPath: caDerPath,
                leafCN: leafCN,
                days: days,
                leafKeyPath: leafKeyPath,
                leafCrtPath: leafCrt,
                leafDerPath: leafDerPath,
                leafKeyDerPath: leafKeyDer,
                verbose: verbose
            )
            leafCrtPath = leafCrt
            leafKeyDerPath = leafKeyDer
        }

        return (caCrtPath, caDerPath, leafCrtPath, leafKeyDerPath)
    }

    private static func escapeOpenSSLSubject(_ cn: String) -> String {
        cn.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "/", with: "\\/")
    }

    private static func generateLeafWithOpenSSL(
        caKeyPath: String,
        caDerPath: String,
        leafCN: String,
        days: Int,
        leafKeyPath: String,
        leafCrtPath: String,
        leafDerPath: String,
        leafKeyDerPath: String,
        verbose: Bool
    ) throws {
        let subjectLeaf = escapeOpenSSLSubject(leafCN)
        try runOpenSSL([
            "genpkey", "-algorithm", "EC", "-pkeyopt", "ec_paramgen_curve:P-256", "-out", leafKeyPath
        ])
        let csrPath = (leafKeyPath as NSString).deletingLastPathComponent + "/leaf.csr"
        try runOpenSSL(["req", "-new", "-key", leafKeyPath, "-out", csrPath, "-subj", "/CN=\(subjectLeaf)"])
        defer { try? FileManager.default.removeItem(atPath: csrPath) }
        try runOpenSSL([
            "x509", "-req", "-in", csrPath, "-CA", caDerPath, "-CAkey", caKeyPath,
            "-out", leafDerPath, "-outform", "DER", "-days", "\(days)",
            "-CAform", "DER", "-CAkeyform", "PEM",
            "-addext", "extendedKeyUsage=codeSigning"
        ])
        try runOpenSSL(["x509", "-in", leafDerPath, "-inform", "DER", "-out", leafCrtPath])
        try runOpenSSL(["pkey", "-in", leafKeyPath, "-outform", "DER", "-out", leafKeyDerPath])
        if verbose { print("   Wrote leaf cert and key") }
    }

    private static func runOpenSSL(_ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["openssl"] + arguments
        let err = Pipe()
        process.standardError = err
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let errData = err.fileHandleForReading.readDataToEndOfFile()
            let errStr = String(data: errData, encoding: .utf8) ?? ""
            throw SPMExtendedError.commandFailed("openssl failed (exit \(process.terminationStatus)): \(errStr.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
    }
}
#endif
