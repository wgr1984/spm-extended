import Foundation
import XCTest

/// Tests for the standalone CLI: direct run and (when Mint is available) run via mint.
final class StandaloneMintTests: XCTestCase {

    static let expectedHelpSubstring = "OVERVIEW: Registry operations"
    static let mintPackageRef = ProcessInfo.processInfo.environment["MINT_PACKAGE_REF"]
        ?? "wgr1984/spm-extended"

    // A dedicated build path so the nested `swift build` doesn't collide with
    // the `.build` directory already locked by the running `swift test` process.
    static let standaloneBuildPath = "/tmp/spm-extended-standalone-test-build"

    /// Path to the package root (two directories up from Tests/StandaloneMintTests/).
    static var packageRoot: String {
        // #filePath == …/Tests/StandaloneMintTests/StandaloneMintTests.swift
        let thisDir    = (#filePath as NSString).deletingLastPathComponent  // …/Tests/StandaloneMintTests
        let testsDir   = (thisDir   as NSString).deletingLastPathComponent  // …/Tests
        return          (testsDir   as NSString).deletingLastPathComponent  // repo root
    }

    /// Resolve the `swift` executable: honour SWIFT_EXEC env var (set by swift test),
    /// then fall back to searching PATH, then /usr/bin/swift.
    static var swiftExecutable: String {
        if let exec = ProcessInfo.processInfo.environment["SWIFT_EXEC"],
           FileManager.default.isExecutableFile(atPath: exec) {
            return exec
        }
        // Walk PATH
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

    /// Spawn `executable` with `arguments`, capture stdout+stderr, return (output, exitCode).
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

    /// Convenience: run a shell command via /bin/sh -c with full PATH.
    @discardableResult
    static func sh(_ command: String, workingDirectory: String? = nil) -> (output: String, exitCode: Int32) {
        run(executable: "/bin/sh",
            arguments: ["-c", command],
            workingDirectory: workingDirectory ?? packageRoot)
    }

    // MARK: - Build helper

    /// Build `spm-extended` into `standaloneBuildPath` and return the path to the binary.
    /// Uses `--build-path` so the nested swift build doesn't conflict with `swift test`'s lock.
    static func buildCLI() -> String? {
        let swift = swiftExecutable
        let buildPath = standaloneBuildPath
        let root = packageRoot

        let (_, buildCode) = run(
            executable: swift,
            arguments: ["build", "--product", "spm-extended", "--build-path", buildPath],
            workingDirectory: root
        )
        guard buildCode == 0 else { return nil }

        // Ask swift where the binary landed
        let (binOut, binCode) = run(
            executable: swift,
            arguments: ["build", "--product", "spm-extended", "--build-path", buildPath, "--show-bin-path"],
            workingDirectory: root
        )
        guard binCode == 0 else { return nil }

        let binPath = binOut.trimmingCharacters(in: .whitespacesAndNewlines)
        let cliPath = (binPath as NSString).appendingPathComponent("spm-extended")
        return FileManager.default.isExecutableFile(atPath: cliPath) ? cliPath : nil
    }

    static let expectedPublishHelpSubstring = "OVERVIEW: Publish to a registry"

    // MARK: - Temp-directory helper

    /// Create a temporary directory, copy Package.swift into it, and return its path.
    /// The caller owns cleanup; use `defer { try? FileManager.default.removeItem(atPath: …) }`.
    static func makeTempPackageDir() throws -> String {
        let tmpDir = "/tmp/spm-test-publish-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
        let src = (packageRoot as NSString).appendingPathComponent("Package.swift")
        let dst = (tmpDir as NSString).appendingPathComponent("Package.swift")
        try FileManager.default.copyItem(atPath: src, toPath: dst)
        return tmpDir
    }

    // MARK: - Tests

    func testStandaloneCLIDirectRun() throws {
        guard let cliPath = Self.buildCLI() else {
            XCTFail("swift build --product spm-extended (--build-path \(Self.standaloneBuildPath)) failed or binary not found")
            return
        }

        // Pass --package-name to prevent the CLI from calling `swift package dump-package`,
        // which would block waiting for the .build lock already held by swift test.
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

    func testStandaloneCLIViaMint() throws {
        let (mintPath, mintCode) = Self.sh("which mint")
        guard mintCode == 0, !mintPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw XCTSkip("Mint not in PATH; install with: brew install mint")
        }

        let ref = Self.mintPackageRef
        var (output, exitCode) = Self.sh("mint run --silent \"\(ref)\" spm-extended registry --help")
        if exitCode != 0 || !output.contains(Self.expectedHelpSubstring) {
            (output, exitCode) = Self.sh("mint run --silent \"\(ref)@main\" spm-extended registry --help")
        }

        let inCI = ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != nil
        if inCI {
            XCTAssertEqual(exitCode, 0, "In CI, mint run should succeed. Output:\n\(output.prefix(600))")
            XCTAssertTrue(
                output.contains(Self.expectedHelpSubstring),
                "Mint run output should contain '\(Self.expectedHelpSubstring)'. Got:\n\(output.prefix(600))"
            )
        } else {
            try XCTSkipIf(
                !output.contains(Self.expectedHelpSubstring),
                "Mint run did not produce expected output (repo not published / network). Output:\n\(output.prefix(300))"
            )
        }
    }

    // MARK: - Publish tests

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

    /// Dry-run publish: runs the full prepare pipeline (Package.json + metadata generation)
    /// but stops before contacting a registry. Uses a temp package dir so it doesn't conflict
    /// with the `.build` lock already held by the parent `swift test` process.
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

        // --package-name skips the initial dump-package in resolveEnvironment.
        // generatePackageJson internally calls `swift package --scratch-path <tmpScratch> dump-package`
        // in tmpDir, which is fully isolated from the running test's .build directory.
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
        XCTAssertTrue(
            output.contains("Dry run"),
            "Output should mention dry run. Got:\n\(output.prefix(800))"
        )
        XCTAssertTrue(
            output.contains("swift package-registry"),
            "Output should contain the generated publish command. Got:\n\(output.prefix(800))"
        )
        XCTAssertTrue(
            output.contains("myorg.test-package") && output.contains("1.0.0"),
            "Generated command should include the package-id and version. Got:\n\(output.prefix(800))"
        )

        // Verify that Package.json was written to the temp package dir.
        let packageJsonPath = (tmpDir as NSString).appendingPathComponent("Package.json")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: packageJsonPath),
            "Package.json should have been created in the temp package dir"
        )
    }

    func testPublishMissingPackageId() throws {
        guard let cliPath = Self.buildCLI() else {
            XCTFail("swift build --product spm-extended failed or binary not found")
            return
        }

        // No positional arguments → missing <package-id>
        let (output, exitCode) = Self.run(
            executable: cliPath,
            arguments: ["--package-name", "test-package", "registry", "publish"]
        )
        XCTAssertNotEqual(exitCode, 0, "Missing package-id should fail")
        XCTAssertTrue(
            output.lowercased().contains("package-id"),
            "Error output should mention 'package-id'. Got:\n\(output.prefix(600))"
        )
    }

    func testPublishMissingVersion() throws {
        guard let cliPath = Self.buildCLI() else {
            XCTFail("swift build --product spm-extended failed or binary not found")
            return
        }

        // One positional argument (package-id) but no version
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

        // Package-id without a dot (no scope.name format)
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

    /// Exercises the full extended publish pipeline (Steps 1–3 in PublishCommand.swift) without
    /// --dry-run. Uses a non-existent local URL so the network call fails predictably, proving
    /// the extended command reaches Step 3 (the actual `swift package-registry publish` invocation)
    /// rather than stopping at the dry-run shortcut.
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

        // No --dry-run: the extended PublishCommand runs all three steps.
        // The fake registry URL causes Step 3 to fail at the network level,
        // but Steps 1 (Package.json) and 2 (metadata) must succeed first.
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

        // Step 1 must have completed before any failure.
        XCTAssertTrue(
            output.contains("Step 1") || output.contains("Package.json"),
            "Extended pipeline should reach Step 1. Output:\n\(output.prefix(800))"
        )

        // Step 3 must have been reached (proves we went through the full pipeline,
        // not the dry-run shortcut).
        XCTAssertTrue(
            output.contains("Step 3") || output.contains("Publishing to registry") || output.contains("Executing:"),
            "Extended pipeline should reach Step 3. Output:\n\(output.prefix(800))"
        )

        // Package.json must have been written by the extended command.
        let packageJsonPath = (tmpDir as NSString).appendingPathComponent("Package.json")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: packageJsonPath),
            "Package.json should have been created by the extended publish pipeline"
        )

        // The publish itself must fail (fake registry URL) — exit code is non-zero.
        XCTAssertNotEqual(exitCode, 0, "Publish to a fake registry should fail. Output:\n\(output.prefix(800))")

        // Must NOT have printed the dry-run shortcut message.
        XCTAssertFalse(
            output.contains("Dry run"),
            "Full-pipeline publish should not contain the dry-run message. Output:\n\(output.prefix(800))"
        )
    }

    func testPublishViaMint() throws {
        let (mintPath, mintCode) = Self.sh("which mint")
        guard mintCode == 0, !mintPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw XCTSkip("Mint not in PATH; install with: brew install mint")
        }

        let ref = Self.mintPackageRef
        var (output, exitCode) = Self.sh(
            "mint run --silent \"\(ref)\" spm-extended --package-name test-package registry publish --help"
        )
        if exitCode != 0 || !output.contains(Self.expectedPublishHelpSubstring) {
            (output, exitCode) = Self.sh(
                "mint run --silent \"\(ref)@main\" spm-extended --package-name test-package registry publish --help"
            )
        }

        let inCI = ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != nil
        if inCI {
            XCTAssertEqual(exitCode, 0, "In CI, mint run should succeed. Output:\n\(output.prefix(600))")
            XCTAssertTrue(
                output.contains(Self.expectedPublishHelpSubstring),
                "Mint run output should contain '\(Self.expectedPublishHelpSubstring)'. Got:\n\(output.prefix(600))"
            )
        } else {
            try XCTSkipIf(
                !output.contains(Self.expectedPublishHelpSubstring),
                "Mint run did not produce expected output (repo not published / network). Output:\n\(output.prefix(300))"
            )
        }
    }
}

