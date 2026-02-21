import Foundation

struct CleanCacheCommand {
    let environment: RunEnvironment

    private let fileManager = FileManager.default

    func execute(arguments: [String]) throws {
        print("🚀 SPM Extended Plugin - Registry Clean Cache")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Package: \(environment.packageName)")
        print("Directory: \(environment.packageDirectory)")
        print()

        var doGlobal = false
        var doLocal = false

        var i = 0
        while i < arguments.count {
            switch arguments[i] {
            case "--global":
                doGlobal = true
            case "--local":
                doLocal = true
            case "--all":
                doGlobal = true
                doLocal = true
            case "--help", "-h":
                printCleanCacheHelp()
                return
            default:
                if arguments[i].hasPrefix("--") {
                    print("⚠️  Warning: Unknown option '\(arguments[i])'")
                }
            }
            i += 1
        }

        if !doGlobal && !doLocal {
            print("Error: Specify at least one of --local, --global, or --all.")
            print()
            printCleanCacheHelp()
            return
        }

        var removed: [String] = []
        var errors: [String] = []

        if doGlobal {
            let (paths, errs) = removeGlobalPaths()
            removed.append(contentsOf: paths)
            errors.append(contentsOf: errs)
        }

        if doLocal {
            let (paths, errs) = removeLocalPaths()
            removed.append(contentsOf: paths)
            errors.append(contentsOf: errs)
        }

        if !removed.isEmpty {
            print("Removed:")
            for p in removed.sorted() {
                print("   ✓ \(p)")
            }
        }
        if !errors.isEmpty {
            for e in errors {
                print("   ⚠️  \(e)")
            }
            if errors.contains(where: { $0.contains("sandbox") || $0.contains("Permission") || $0.contains("permission") }) {
                print()
                print("Tip: If the plugin runs in a sandbox, use --disable-sandbox:")
                print("   swift package --disable-sandbox registry clean-cache --local   # or --global / --all")
            }
        }
        if removed.isEmpty && errors.isEmpty {
            print("Nothing to remove (paths did not exist).")
        }
    }

    private func removeGlobalPaths() -> (removed: [String], errors: [String]) {
        let home = ProcessInfo.processInfo.environment["HOME"]
            ?? NSString(string: fileManager.homeDirectoryForCurrentUser.path).expandingTildeInPath
        let swiftPM = (home as NSString).appendingPathComponent(".swiftpm")
        let cacheDir = (swiftPM as NSString).appendingPathComponent("cache")
        let fingerprintsDir = (swiftPM as NSString).appendingPathComponent("security/fingerprints")

        var removed: [String] = []
        var errors: [String] = []

        for dir in [cacheDir, fingerprintsDir] {
            if fileManager.fileExists(atPath: dir) {
                do {
                    try fileManager.removeItem(atPath: dir)
                    removed.append(dir)
                } catch {
                    errors.append("Could not remove \(dir): \(error.localizedDescription)")
                }
            }
        }

        return (removed, errors)
    }

    private func removeLocalPaths() -> (removed: [String], errors: [String]) {
        let buildDir = environment.path(components: ".build")
        let fingerprintsDir = environment.path(components: ".swiftpm", "security", "fingerprints")
        let swiftpmCache = environment.path(components: ".swiftpm", "cache")

        var removed: [String] = []
        var errors: [String] = []

        for dir in [buildDir, fingerprintsDir, swiftpmCache] {
            if fileManager.fileExists(atPath: dir) {
                do {
                    try fileManager.removeItem(atPath: dir)
                    removed.append(dir)
                } catch {
                    errors.append("Could not remove \(dir): \(error.localizedDescription)")
                }
            }
        }

        return (removed, errors)
    }

    private func printCleanCacheHelp() {
        print("""
        OVERVIEW: Clean SPM registry package caches and fingerprints/checksums

        USAGE: swift package registry clean-cache (--local | --global | --all)

        DESCRIPTION:
          --global   Clean user-level data: ~/.swiftpm/cache and ~/.swiftpm/security/fingerprints.
          --local    Clean this package only: .build and .swiftpm cache/fingerprints.
          --all      Clean both global and local.

        OPTIONS:
          --local    Clean only this package's build and cache data
          --global   Clean only global ~/.swiftpm cache and fingerprints
          --all      Clean both global and local
          -h, --help Show this help

        EXAMPLES:
          swift package registry clean-cache --local
          swift package --disable-sandbox registry clean-cache --global
          swift package --disable-sandbox registry clean-cache --all
        """)
    }
}
