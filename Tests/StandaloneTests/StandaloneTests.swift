import Foundation
import XCTest

/// Tests for the standalone CLI: direct run (no Mint), plus plugin version.
/// Runs on macOS and Linux.
///
/// Run from the **package root** so the test process can find Package.swift. To avoid
/// deadlock with the repo `.build` directory, use a scratch path for the test run:
///
///     swift test --scratch-path /tmp/spm-extended-test-run --filter StandaloneTests
///
/// If you see "Another instance of SwiftPM (PID: N) is already running", kill that process
/// (e.g. `kill N`) or use the above so the runner does not lock `.build`.
final class StandaloneTests: XCTestCase {

    static let expectedHelpSubstring = "OVERVIEW: Registry operations"
    static let expectedPublishHelpSubstring = "OVERVIEW: Publish to a registry"
    static let expectedListHelpSubstring = "List available versions"
    static let expectedVerifyHelpSubstring = "Verify a package release"

    /// Scratch path for nested `swift build` so it does not lock the same `.build` as `swift test`.
    static let standaloneBuildPath = "/tmp/spm-extended-standalone-test-build"
    /// Scratch path for `swift package registry ...` so plugin invocations do not lock `.build` (deadlock with `swift test`).
    static let pluginTestScratchPath = "/tmp/spm-extended-plugin-test-scratch"

    static var packageRoot: String {
        let thisDir    = (#filePath as NSString).deletingLastPathComponent
        let testsDir   = (thisDir   as NSString).deletingLastPathComponent
        return          (testsDir   as NSString).deletingLastPathComponent
    }

    static var swiftExecutable: String {
        if let exec = ProcessInfo.processInfo.environment["SWIFT_EXEC"],
           FileManager.default.isExecutableFile(atPath: exec) {
            return exec
        }
        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for component in path.split(separator: ":") {
            let candidate = (String(component) as NSString).appendingPathComponent("swift")
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return "/usr/bin/swift"
    }

    // MARK: - Process helpers

    @discardableResult
    static func run(
        executable: String,
        arguments: [String],
        workingDirectory: String? = nil,
        additionalEnv: [String: String] = [:]
    ) -> (output: String, exitCode: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let dir = workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: dir)
        }
        if !additionalEnv.isEmpty {
            var env = ProcessInfo.processInfo.environment
            for (k, v) in additionalEnv { env[k] = v }
            process.environment = env
        }
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError  = errPipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ("\(error)", -1)
        }
        let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (out + err, process.terminationStatus)
    }

    @discardableResult
    static func sh(_ command: String, workingDirectory: String? = nil) -> (output: String, exitCode: Int32) {
        run(executable: "/bin/sh",
            arguments: ["-c", command],
            workingDirectory: workingDirectory ?? packageRoot)
    }

    // MARK: - Build helper

    static func buildCLI() -> String? {
        let swift = swiftExecutable
        let buildPath = standaloneBuildPath
        let root = packageRoot

        let (_, buildCode) = run(
            executable: swift,
            arguments: ["build", "--product", "spm-extended", "--scratch-path", buildPath],
            workingDirectory: root
        )
        guard buildCode == 0 else { return nil }

        let (binOut, binCode) = run(
            executable: swift,
            arguments: ["build", "--product", "spm-extended", "--scratch-path", buildPath, "--show-bin-path"],
            workingDirectory: root
        )
        guard binCode == 0 else { return nil }

        let binPath = binOut.trimmingCharacters(in: .whitespacesAndNewlines)
        let cliPath = (binPath as NSString).appendingPathComponent("spm-extended")
        return FileManager.default.isExecutableFile(atPath: cliPath) ? cliPath : nil
    }

    static func makeTempPackageDir() throws -> String {
        let tmpDir = "/tmp/spm-test-standalone-publish-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
        let src = (packageRoot as NSString).appendingPathComponent("Package.swift")
        let dst = (tmpDir as NSString).appendingPathComponent("Package.swift")
        try FileManager.default.copyItem(atPath: src, toPath: dst)
        return tmpDir
    }

    /// Version string is expected to be "v" followed by semver (e.g. v0.1.3).
    private static func isVersionOutput(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.hasPrefix("v"), t.count > 1 else { return false }
        let rest = String(t.dropFirst())
        let parts = rest.split(separator: ".", omittingEmptySubsequences: false)
        return parts.count >= 2 && parts.allSatisfy { $0.allSatisfy(\.isNumber) }
    }

    // MARK: - Version tests (CLI + plugin)

    func testCLIVersion() throws {
        guard let cliPath = Self.buildCLI() else {
            XCTFail("swift build --product spm-extended failed or binary not found")
            return
        }

        var (output, exitCode) = Self.run(executable: cliPath, arguments: ["--version"], workingDirectory: Self.packageRoot)
        XCTAssertEqual(exitCode, 0, "spm-extended --version should exit 0. Output:\n\(output)")
        XCTAssertTrue(Self.isVersionOutput(output), "Output should be a version string (e.g. v0.1.3). Got:\n\(output.prefix(200))")

        (output, exitCode) = Self.run(executable: cliPath, arguments: ["-V"], workingDirectory: Self.packageRoot)
        XCTAssertEqual(exitCode, 0, "spm-extended -V should exit 0. Output:\n\(output)")
        XCTAssertTrue(Self.isVersionOutput(output), "Output should be a version string. Got:\n\(output.prefix(200))")
    }

    func testPluginVersion() throws {
        let (output, exitCode) = Self.run(
            executable: Self.swiftExecutable,
            arguments: ["package", "--scratch-path", Self.pluginTestScratchPath, "registry", "--version"],
            workingDirectory: Self.packageRoot
        )
        XCTAssertEqual(exitCode, 0, "swift package registry --version should exit 0. Output:\n\(output)")
        XCTAssertTrue(Self.isVersionOutput(output), "Plugin version output should be a version string (e.g. v0.1.3). Got:\n\(output.prefix(200))")
    }

    func testCLIAndPluginVersionMatch() throws {
        guard let cliPath = Self.buildCLI() else {
            XCTFail("swift build --product spm-extended failed or binary not found")
            return
        }

        let (cliOut, cliCode) = Self.run(executable: cliPath, arguments: ["--version"], workingDirectory: Self.packageRoot)
        XCTAssertEqual(cliCode, 0, "CLI --version should succeed")
        let cliVersion = cliOut.split(separator: "\n").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let (pluginOut, pluginCode) = Self.run(
            executable: Self.swiftExecutable,
            arguments: ["package", "--scratch-path", Self.pluginTestScratchPath, "registry", "--version"],
            workingDirectory: Self.packageRoot
        )
        XCTAssertEqual(pluginCode, 0, "Plugin --version should succeed")
        let pluginVersion = pluginOut.split(separator: "\n").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        XCTAssertEqual(cliVersion, pluginVersion, "CLI and plugin should report the same version. CLI: '\(cliVersion)' Plugin: '\(pluginVersion)'")
    }

    // MARK: - Standalone CLI tests

    func testStandaloneCLIDirectRun() throws {
        guard let cliPath = Self.buildCLI() else {
            XCTFail("swift build --product spm-extended (--scratch-path \(Self.standaloneBuildPath)) failed or binary not found")
            return
        }

        let (output, exitCode) = Self.run(
            executable: cliPath,
            arguments: ["--package-name", "test-package", "registry", "--help"],
            workingDirectory: Self.packageRoot
        )
        XCTAssertEqual(exitCode, 0, "spm-extended registry --help should exit 0")
        XCTAssertTrue(
            output.contains(Self.expectedHelpSubstring),
            "Output should contain '\(Self.expectedHelpSubstring)'. Got:\n\(output.prefix(600))"
        )
    }

    func testPublishHelp() throws {
        guard let cliPath = Self.buildCLI() else {
            XCTFail("swift build --product spm-extended failed or binary not found")
            return
        }

        let (output, exitCode) = Self.run(
            executable: cliPath,
            arguments: ["--package-name", "test-package", "registry", "publish", "--help"]
        )
        XCTAssertEqual(exitCode, 0, "registry publish --help should exit 0. Output:\n\(output.prefix(600))")
        XCTAssertTrue(
            output.contains(Self.expectedPublishHelpSubstring),
            "Output should contain '\(Self.expectedPublishHelpSubstring)'. Got:\n\(output.prefix(600))"
        )
    }

    func testPublishDryRun() throws {
        guard let cliPath = Self.buildCLI() else {
            XCTFail("swift build --product spm-extended failed or binary not found")
            return
        }

        let tmpDir = try Self.makeTempPackageDir()
        let tmpScratch = tmpDir + "-scratch"
        defer {
            try? FileManager.default.removeItem(atPath: tmpDir)
            try? FileManager.default.removeItem(atPath: tmpScratch)
        }

        let (output, exitCode) = Self.run(
            executable: cliPath,
            arguments: [
                "--package-name", "test-package",
                "--package-path", tmpDir,
                "registry", "publish",
                "myorg.test-package", "1.0.0",
                "--dry-run",
                "--scratch-directory", tmpScratch,
            ]
        )
        XCTAssertEqual(exitCode, 0, "Dry-run publish should exit 0. Output:\n\(output.prefix(800))")
        XCTAssertTrue(output.contains("Dry run"), "Output should mention dry run. Got:\n\(output.prefix(800))")
        XCTAssertTrue(output.contains("swift package-registry"), "Output should contain the generated publish command. Got:\n\(output.prefix(800))")
        XCTAssertTrue(output.contains("myorg.test-package") && output.contains("1.0.0"), "Generated command should include the package-id and version. Got:\n\(output.prefix(800))")

        let packageJsonPath = (tmpDir as NSString).appendingPathComponent("Package.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: packageJsonPath), "Package.json should have been created in the temp package dir")
    }

    func testPublishMissingPackageId() throws {
        guard let cliPath = Self.buildCLI() else {
            XCTFail("swift build --product spm-extended failed or binary not found")
            return
        }

        let (output, exitCode) = Self.run(
            executable: cliPath,
            arguments: ["--package-name", "test-package", "registry", "publish"]
        )
        XCTAssertNotEqual(exitCode, 0, "Missing package-id should fail")
        XCTAssertTrue(output.lowercased().contains("package-id"), "Error output should mention 'package-id'. Got:\n\(output.prefix(600))")
    }

    func testPublishMissingVersion() throws {
        guard let cliPath = Self.buildCLI() else {
            XCTFail("swift build --product spm-extended failed or binary not found")
            return
        }

        let (output, exitCode) = Self.run(
            executable: cliPath,
            arguments: ["--package-name", "test-package", "registry", "publish", "myorg.test-package"]
        )
        XCTAssertNotEqual(exitCode, 0, "Missing version should fail")
        XCTAssertTrue(
            output.lowercased().contains("package-version") || output.lowercased().contains("version"),
            "Error output should mention version. Got:\n\(output.prefix(600))"
        )
    }

    func testPublishInvalidPackageId() throws {
        guard let cliPath = Self.buildCLI() else {
            XCTFail("swift build --product spm-extended failed or binary not found")
            return
        }

        let (output, exitCode) = Self.run(
            executable: cliPath,
            arguments: ["--package-name", "test-package", "registry", "publish", "invalid-no-dot", "1.0.0"]
        )
        XCTAssertNotEqual(exitCode, 0, "Invalid package-id format should fail")
        XCTAssertTrue(
            output.contains("scope.name") || output.contains("scope") || output.contains("format"),
            "Error output should mention expected format. Got:\n\(output.prefix(600))"
        )
    }

    func testPublishFullPipelineReachesRegistryStep() throws {
        guard let cliPath = Self.buildCLI() else {
            XCTFail("swift build --product spm-extended failed or binary not found")
            return
        }

        let tmpDir = try Self.makeTempPackageDir()
        let tmpScratch = tmpDir + "-scratch"
        defer {
            try? FileManager.default.removeItem(atPath: tmpDir)
            try? FileManager.default.removeItem(atPath: tmpScratch)
        }

        let (output, exitCode) = Self.run(
            executable: cliPath,
            arguments: [
                "--package-name", "test-package",
                "--package-path", tmpDir,
                "registry", "publish",
                "myorg.test-package", "1.0.0",
                "--url", "https://localhost:59999",
                "--scratch-directory", tmpScratch,
            ]
        )

        XCTAssertTrue(
            output.contains("Step 1") || output.contains("Package.json"),
            "Extended pipeline should reach Step 1. Output:\n\(output.prefix(800))"
        )
        XCTAssertTrue(
            output.contains("Step 3") || output.contains("Publishing to registry") || output.contains("Executing:"),
            "Extended pipeline should reach Step 3. Output:\n\(output.prefix(800))"
        )

        let packageJsonPath = (tmpDir as NSString).appendingPathComponent("Package.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: packageJsonPath), "Package.json should have been created by the extended publish pipeline")
        XCTAssertNotEqual(exitCode, 0, "Publish to a fake registry should fail. Output:\n\(output.prefix(800))")
        XCTAssertFalse(output.contains("Dry run"), "Full-pipeline publish should not contain the dry-run message. Output:\n\(output.prefix(800))")
    }

    // MARK: - List command tests

    func testListHelp() throws {
        guard let cliPath = Self.buildCLI() else {
            XCTFail("swift build --product spm-extended failed or binary not found")
            return
        }

        let (output, exitCode) = Self.run(
            executable: cliPath,
            arguments: ["--package-name", "test-package", "registry", "list", "--help"]
        )
        XCTAssertEqual(exitCode, 0, "registry list --help should exit 0. Output:\n\(output.prefix(600))")
        XCTAssertTrue(output.contains(Self.expectedListHelpSubstring), "Output should contain '\(Self.expectedListHelpSubstring)'. Got:\n\(output.prefix(600))")
    }

    func testListMissingPackageId() throws {
        guard let cliPath = Self.buildCLI() else {
            XCTFail("swift build --product spm-extended failed or binary not found")
            return
        }

        let (output, exitCode) = Self.run(
            executable: cliPath,
            arguments: ["--package-name", "test-package", "registry", "list"]
        )
        XCTAssertNotEqual(exitCode, 0, "Missing package-id should fail")
        XCTAssertTrue(output.lowercased().contains("package-id"), "Error output should mention 'package-id'. Got:\n\(output.prefix(600))")
    }

    func testListInvalidPackageId() throws {
        guard let cliPath = Self.buildCLI() else {
            XCTFail("swift build --product spm-extended failed or binary not found")
            return
        }

        let (output, exitCode) = Self.run(
            executable: cliPath,
            arguments: ["--package-name", "test-package", "registry", "list", "invalid-no-dot", "--url", "https://packages.swift.org"]
        )
        XCTAssertNotEqual(exitCode, 0, "Invalid package-id format should fail")
        XCTAssertTrue(
            output.contains("scope.name") || output.contains("scope") || output.contains("format"),
            "Error output should mention expected format. Got:\n\(output.prefix(600))"
        )
    }

    // MARK: - Verify command tests

    func testVerifyHelp() throws {
        guard let cliPath = Self.buildCLI() else {
            XCTFail("swift build --product spm-extended failed or binary not found")
            return
        }

        let (output, exitCode) = Self.run(
            executable: cliPath,
            arguments: ["--package-name", "test-package", "registry", "verify", "--help"]
        )
        XCTAssertEqual(exitCode, 0, "registry verify --help should exit 0. Output:\n\(output.prefix(600))")
        XCTAssertTrue(output.contains(Self.expectedVerifyHelpSubstring), "Output should contain '\(Self.expectedVerifyHelpSubstring)'. Got:\n\(output.prefix(600))")
    }

    func testVerifyMissingPackageId() throws {
        guard let cliPath = Self.buildCLI() else {
            XCTFail("swift build --product spm-extended failed or binary not found")
            return
        }

        let (output, exitCode) = Self.run(
            executable: cliPath,
            arguments: ["--package-name", "test-package", "registry", "verify"]
        )
        XCTAssertNotEqual(exitCode, 0, "Missing package-id should fail")
        XCTAssertTrue(output.lowercased().contains("package-id"), "Error output should mention 'package-id'. Got:\n\(output.prefix(600))")
    }

    func testVerifyMissingVersion() throws {
        guard let cliPath = Self.buildCLI() else {
            XCTFail("swift build --product spm-extended failed or binary not found")
            return
        }

        let (output, exitCode) = Self.run(
            executable: cliPath,
            arguments: ["--package-name", "test-package", "registry", "verify", "myorg.MyPackage"]
        )
        XCTAssertNotEqual(exitCode, 0, "Missing version should fail")
        XCTAssertTrue(output.lowercased().contains("version"), "Error output should mention 'version'. Got:\n\(output.prefix(600))")
    }

    func testVerifyInvalidPackageId() throws {
        guard let cliPath = Self.buildCLI() else {
            XCTFail("swift build --product spm-extended failed or binary not found")
            return
        }

        let (output, exitCode) = Self.run(
            executable: cliPath,
            arguments: ["--package-name", "test-package", "registry", "verify", "invalid-no-dot", "1.0.0", "--url", "https://packages.swift.org"]
        )
        XCTAssertNotEqual(exitCode, 0, "Invalid package-id format should fail")
        XCTAssertTrue(
            output.contains("scope.name") || output.contains("scope") || output.contains("format"),
            "Error output should mention expected format. Got:\n\(output.prefix(600))"
        )
    }
}
