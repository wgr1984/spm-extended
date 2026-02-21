import Foundation
import CryptoKit

/// Pure Swift EC P-256 certificate generation for package signing (no OpenSSL).
/// Produces DER/PEM and PKCS#8 key format compatible with SwiftPM registry publish.
///
/// Aligned with [Swift Package Manager](https://github.com/swiftlang/swift-package-manager):
/// - PackageSigning uses X509 (swift-certificates) and expects ECDSA P-256, SHA-256, CMS format `cms-1.0.0`.
/// - We generate the same algorithm (ecdsa-with-SHA256), SubjectPublicKeyInfo (P-256), and for the leaf cert
///   extendedKeyUsage = codeSigning. The host `swift package registry publish` uses these files for signing.
/// - SwiftPM plugins cannot depend on library products, so we use CryptoKit + minimal DER here instead of swift-certificates.
enum SwiftSigningCertificate {

    enum CertificateLoadError: Error, CustomStringConvertible {
        case missingFiles(String)
        case invalidPEM(String)
        case invalidDER(String)
        var description: String {
            switch self {
            case .missingFiles(let m): return m
            case .invalidPEM(let m): return "Invalid PEM: \(m)"
            case .invalidDER(let m): return "Invalid DER: \(m)"
            }
        }
    }

    // MARK: - OIDs (DER-encoded as needed)
    static let idEcPublicKey: [UInt8] = [0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01]
    static let prime256v1: [UInt8] = [0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07]
    static let ecdsaWithSHA256: [UInt8] = [0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x04, 0x03, 0x02]
    static let commonName: [UInt8] = [0x55, 0x04, 0x03]
    static let extendedKeyUsage: [UInt8] = [0x55, 0x1D, 0x25]
    static let codeSigning: [UInt8] = [0x2B, 0x06, 0x01, 0x05, 0x05, 0x07, 0x03, 0x03]
    static let basicConstraints: [UInt8] = [0x55, 0x1D, 0x13]

    // MARK: - DER helpers

    private static func derLength(_ n: Int) -> [UInt8] {
        if n < 128 {
            return [UInt8(n)]
        }
        var len = n
        var bytes: [UInt8] = []
        while len > 0 {
            bytes.insert(UInt8(len & 0xFF), at: 0)
            len >>= 8
        }
        return [UInt8(0x80 | bytes.count)] + bytes
    }

    private static func derTag(_ tag: UInt8, _ body: [UInt8]) -> [UInt8] {
        [tag] + derLength(body.count) + body
    }

    private static func derOID(_ oid: [UInt8]) -> [UInt8] {
        derTag(0x06, oid)
    }

    private static func derInteger(_ bytes: [UInt8]) -> [UInt8] {
        var b = bytes
        if b.isEmpty { b = [0] }
        if b.first! >= 0x80 { b.insert(0, at: 0) }
        return derTag(0x02, b)
    }

    private static func derNull() -> [UInt8] {
        derTag(0x05, [])
    }

    private static func derBoolean(_ value: Bool) -> [UInt8] {
        derTag(0x01, [value ? 0xFF : 0x00])
    }

    private static func derSequence(_ body: [UInt8]) -> [UInt8] {
        derTag(0x30, body)
    }

    private static func derSet(_ body: [UInt8]) -> [UInt8] {
        derTag(0x31, body)
    }

    private static func derExplicit(tag: UInt8, _ body: [UInt8]) -> [UInt8] {
        derTag(0xA0 | tag, body)
    }

    private static func derUTF8String(_ s: String) -> [UInt8] {
        let bytes = Array(s.utf8)
        return derTag(0x0C, bytes)
    }

    private static func derOctetString(_ bytes: [UInt8]) -> [UInt8] {
        derTag(0x04, bytes)
    }

    private static func derBitString(_ bytes: [UInt8], unusedBits: UInt8 = 0) -> [UInt8] {
        derTag(0x03, [unusedBits] + bytes)
    }

    private static func derGeneralizedTime(_ date: Date) -> [UInt8] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let str = formatter.string(from: date)
        return derTag(0x18, Array(str.utf8))
    }

    private static func derName(cn: String) -> [UInt8] {
        let attr = derSequence(derOID(commonName) + derUTF8String(cn))
        let rdn = derSet(attr)
        return derSequence(rdn)
    }

    private static func derAlgorithmIdentifier(oid: [UInt8], paramsNull: Bool = true) -> [UInt8] {
        var parts = derOID(oid)
        if paramsNull { parts += derNull() }
        return derSequence(parts)
    }

    private static func derSubjectPublicKeyInfo(publicKey: P256.Signing.PublicKey) -> [UInt8] {
        let alg = derSequence(derOID(idEcPublicKey) + derOID(prime256v1))
        let keyBytes = publicKey.x963Representation
        let keyBitString = derBitString(Array(keyBytes))
        return derSequence(alg + keyBitString)
    }

    private static func derValidity(notBefore: Date, notAfter: Date) -> [UInt8] {
        derSequence(derGeneralizedTime(notBefore) + derGeneralizedTime(notAfter))
    }

    private static func randomSerial() -> [UInt8] {
        var bytes = (0..<20).map { _ in UInt8.random(in: 0...255) }
        if bytes.first == 0 { bytes[0] = 1 }
        return bytes
    }

    private static func derBasicConstraintsCA() -> [UInt8] {
        let value = derSequence(derBoolean(true))
        return derSequence(derOID(basicConstraints) + derBoolean(true) + derOctetString(value))
    }

    private static func derExtendedKeyUsageCodeSigning() -> [UInt8] {
        let ekuValue = derSequence(derOID(codeSigning))
        let ext = derSequence(derOID(extendedKeyUsage) + derOctetString(ekuValue))
        return ext
    }

    private static func buildTBSCertificate(
        version: Int,
        serial: [UInt8],
        issuer: [UInt8],
        notBefore: Date,
        notAfter: Date,
        subject: [UInt8],
        subjectPublicKeyInfo: [UInt8],
        extensions: [UInt8]?
    ) -> [UInt8] {
        var parts: [UInt8] = []
        if version != 0 {
            parts += derExplicit(tag: 0, derInteger([UInt8(version)]))
        }
        parts += derInteger(serial)
        parts += derAlgorithmIdentifier(oid: ecdsaWithSHA256, paramsNull: false)
        parts += issuer
        parts += derValidity(notBefore: notBefore, notAfter: notAfter)
        parts += subject
        parts += subjectPublicKeyInfo
        if let ext = extensions {
            parts += derExplicit(tag: 3, derSequence(ext))
        }
        return derSequence(parts)
    }

    private static func signCertificate(
        tbsDER: [UInt8],
        privateKey: P256.Signing.PrivateKey
    ) throws -> [UInt8] {
        let signature = try privateKey.signature(for: Data(tbsDER))
        let sigDER = Array(signature.derRepresentation)
        let cert = derSequence(
            tbsDER +
            derAlgorithmIdentifier(oid: ecdsaWithSHA256, paramsNull: false) +
            derBitString(sigDER)
        )
        return cert
    }

    private static func derReadTLV(_ bytes: [UInt8], _ offset: Int) throws -> (start: Int, end: Int, next: Int) {
        guard offset < bytes.count else { throw CertificateLoadError.invalidDER("truncated") }
        _ = bytes[offset]
        var pos = offset + 1
        guard pos < bytes.count else { throw CertificateLoadError.invalidDER("truncated length") }
        var len = Int(bytes[pos])
        pos += 1
        if len & 0x80 != 0 {
            let numLen = len & 0x7F
            guard numLen <= 4, pos + numLen <= bytes.count else { throw CertificateLoadError.invalidDER("long length") }
            len = 0
            for _ in 0..<numLen {
                len = (len << 8) | Int(bytes[pos])
                pos += 1
            }
        }
        let valueEnd = pos + len
        guard valueEnd <= bytes.count else { throw CertificateLoadError.invalidDER("value overflow") }
        return (offset, valueEnd, valueEnd)
    }

    static func extractSubjectFromCertDER(_ certDER: [UInt8]) throws -> [UInt8] {
        var pos = 0
        _ = try derReadTLV(certDER, pos)
        guard certDER[pos] == 0x30 else { throw CertificateLoadError.invalidDER("cert not SEQUENCE") }
        (_, _, pos) = try derReadTLV(certDER, pos)
        (_, _, pos) = try derReadTLV(certDER, pos)
        guard certDER[pos] == 0x30 else { throw CertificateLoadError.invalidDER("tbs not SEQUENCE") }
        (_, _, pos) = try derReadTLV(certDER, pos)
        if pos < certDER.count && certDER[pos] == 0xA0 {
            (_, _, pos) = try derReadTLV(certDER, pos)
        }
        for _ in 0..<4 {
            (_, _, pos) = try derReadTLV(certDER, pos)
        }
        let (subjStart, subjEnd, _) = try derReadTLV(certDER, pos)
        return Array(certDER[subjStart..<subjEnd])
    }

    static func loadCA(caDir: String) throws -> (privateKey: P256.Signing.PrivateKey, subjectDER: [UInt8]) {
        let caKeyPath = (caDir as NSString).appendingPathComponent("ca.key")
        let caDerPath = (caDir as NSString).appendingPathComponent("ca.der")
        guard fileManager.fileExists(atPath: caKeyPath), fileManager.fileExists(atPath: caDerPath) else {
            throw CertificateLoadError.missingFiles("ca.key and ca.der must exist in \(caDir)")
        }
        let pemContent = try String(contentsOfFile: caKeyPath, encoding: .utf8)
        let derData = try pemToDER(pemContent, label: "PRIVATE KEY")
        let caKey = try P256.Signing.PrivateKey(derRepresentation: derData)
        let certDER = try Data(contentsOf: URL(fileURLWithPath: caDerPath))
        let subjectDER = try extractSubjectFromCertDER(Array(certDER))
        return (caKey, subjectDER)
    }

    private static let fileManager = FileManager.default

    private static func pemToDER(_ pem: String, label: String) throws -> Data {
        let lines = pem.components(separatedBy: .newlines)
        guard let beginIdx = lines.firstIndex(where: { $0.hasPrefix("-----BEGIN") }),
              let endIdx = lines.firstIndex(where: { $0.hasPrefix("-----END") }),
              beginIdx < endIdx else {
            throw CertificateLoadError.invalidPEM("missing BEGIN/END \(label)")
        }
        let base64 = lines[lines.index(after: beginIdx)..<endIdx].joined()
        guard let data = Data(base64Encoded: base64) else {
            throw CertificateLoadError.invalidPEM("base64 decode failed")
        }
        return data
    }

    static func pemWrap(der: Data, label: String) -> String {
        let b64 = der.base64EncodedString()
        let lines = stride(from: 0, to: b64.count, by: 64).map { i in
            String(b64[b64.index(b64.startIndex, offsetBy: i)..<b64.index(b64.startIndex, offsetBy: min(i + 64, b64.count))])
        }
        return "-----BEGIN \(label)-----\n" + lines.joined(separator: "\n") + "\n-----END \(label)-----\n"
    }

    static func generateCA(outputDir: String, caCN: String, validityYears: Int = 10, verbose: Bool) throws -> (privateKey: P256.Signing.PrivateKey, certDER: Data) {
        let caKey = P256.Signing.PrivateKey()
        let subject = derName(cn: caCN)
        let notBefore = Date()
        let notAfter = Calendar.current.date(byAdding: .year, value: validityYears, to: notBefore)!
        let spki = derSubjectPublicKeyInfo(publicKey: caKey.publicKey)
        let tbs = buildTBSCertificate(
            version: 2,
            serial: randomSerial(),
            issuer: subject,
            notBefore: notBefore,
            notAfter: notAfter,
            subject: subject,
            subjectPublicKeyInfo: spki,
            extensions: derBasicConstraintsCA()
        )
        let certDER = try signCertificate(tbsDER: tbs, privateKey: caKey)
        let certData = Data(certDER)

        let caKeyPath = (outputDir as NSString).appendingPathComponent("ca.key")
        let caCrtPath = (outputDir as NSString).appendingPathComponent("ca.crt")
        let caDerPath = (outputDir as NSString).appendingPathComponent("ca.der")

        let keyPEM = pemWrap(der: caKey.derRepresentation, label: "PRIVATE KEY")
        try keyPEM.write(to: URL(fileURLWithPath: caKeyPath), atomically: true, encoding: .utf8)
        try pemWrap(der: certData, label: "CERTIFICATE").write(to: URL(fileURLWithPath: caCrtPath), atomically: true, encoding: .utf8)
        try certData.write(to: URL(fileURLWithPath: caDerPath))

        if verbose { print("   Wrote \(caKeyPath), \(caCrtPath), \(caDerPath)") }
        return (caKey, certData)
    }

    static func generateLeafCert(
        outputDir: String,
        caPrivateKey: P256.Signing.PrivateKey,
        caSubjectDER: [UInt8],
        leafCN: String,
        validityYears: Int = 10,
        verbose: Bool
    ) throws -> (leafCrtPath: String, leafKeyDerPath: String) {
        let leafKey = P256.Signing.PrivateKey()
        let subject = derName(cn: leafCN)
        let notBefore = Date()
        let notAfter = Calendar.current.date(byAdding: .year, value: validityYears, to: notBefore)!
        let spki = derSubjectPublicKeyInfo(publicKey: leafKey.publicKey)
        let ekuExt = derExtendedKeyUsageCodeSigning()
        let tbs = buildTBSCertificate(
            version: 2,
            serial: randomSerial(),
            issuer: caSubjectDER,
            notBefore: notBefore,
            notAfter: notAfter,
            subject: subject,
            subjectPublicKeyInfo: spki,
            extensions: ekuExt
        )
        let certDER = try signCertificate(tbsDER: tbs, privateKey: caPrivateKey)
        let certData = Data(certDER)

        let leafKeyPath = (outputDir as NSString).appendingPathComponent("leaf.key")
        let leafCrtPath = (outputDir as NSString).appendingPathComponent("leaf.crt")
        let leafDerPath = (outputDir as NSString).appendingPathComponent("leaf.der")
        let leafKeyDerPath = (outputDir as NSString).appendingPathComponent("leaf.key.der")

        try pemWrap(der: leafKey.derRepresentation, label: "PRIVATE KEY").write(to: URL(fileURLWithPath: leafKeyPath), atomically: true, encoding: .utf8)
        try pemWrap(der: certData, label: "CERTIFICATE").write(to: URL(fileURLWithPath: leafCrtPath), atomically: true, encoding: .utf8)
        try certData.write(to: URL(fileURLWithPath: leafDerPath))
        try leafKey.derRepresentation.write(to: URL(fileURLWithPath: leafKeyDerPath))

        if verbose { print("   Wrote leaf cert and key") }
        return (leafCrtPath, leafKeyDerPath)
    }

    static func caSubjectDER(caCN: String) -> [UInt8] {
        derName(cn: caCN)
    }
}
