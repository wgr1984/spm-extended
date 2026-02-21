import Foundation
import SPMExtendedCore

func main() {
    let arguments = Array(CommandLine.arguments.dropFirst())

    guard !arguments.isEmpty, arguments[0] != "--help", arguments[0] != "-h" else {
        printTopLevelHelp()
        exit(0)
    }

    let topLevel = arguments[0]
    let remaining = Array(arguments.dropFirst())

    do {
        let (packagePath, packageName, swiftPath, argsForCommand) = try resolveEnvironment(arguments: remaining)
        let env = RunEnvironment(
            packageDirectory: packagePath,
            packageName: packageName,
            swiftPath: swiftPath
        )

        switch topLevel {
        case "registry":
            try RegistryRunner.run(environment: env, arguments: argsForCommand)
        case "outdated":
            try OutdatedRunner.run(environment: env, arguments: argsForCommand)
        case "help":
            printTopLevelHelp()
        default:
            print("Unknown command: \(topLevel)")
            print("Use 'registry' or 'outdated'. See --help.")
            exit(1)
        }
    } catch let error as SPMExtendedError {
        fputs("\(error.description)\n", stderr)
        exit(1)
    } catch {
        fputs("\(error)\n", stderr)
        exit(1)
    }
}

/// Parse --package-path and --package-name from arguments; return (packagePath, packageName, swiftPath, argsWithoutGlobals).
func resolveEnvironment(arguments: [String]) throws -> (packagePath: String, packageName: String, swiftPath: String, argsForCommand: [String]) {
    var packagePath: String?
    var packageName: String?
    var argsForCommand: [String] = []
    var i = 0
    while i < arguments.count {
        switch arguments[i] {
        case "--package-path":
            i += 1
            if i < arguments.count {
                packagePath = arguments[i]
                i += 1
                continue
            }
        case "--package-name":
            i += 1
            if i < arguments.count {
                packageName = arguments[i]
                i += 1
                continue
            }
        default:
            argsForCommand.append(arguments[i])
            i += 1
        }
    }

    let resolvedPath = packagePath ?? FileManager.default.currentDirectoryPath
    let resolvedName: String
    if let n = packageName {
        resolvedName = n
    } else {
        resolvedName = try resolvePackageName(packageDirectory: resolvedPath)
    }
    let resolvedSwift = resolveSwiftPath()

    return (resolvedPath, resolvedName, resolvedSwift, argsForCommand)
}

/// Run `swift package dump-package` and parse "name" from JSON.
func resolvePackageName(packageDirectory: String) throws -> String {
    let swiftPath = resolveSwiftPath()
    let pipe = Pipe()
    let process = Process()
    process.executableURL = URL(fileURLWithPath: swiftPath)
    process.arguments = ["package", "dump-package"]
    process.currentDirectoryURL = URL(fileURLWithPath: packageDirectory)
    process.standardOutput = pipe
    process.standardError = Pipe()
    try process.run()
    process.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard process.terminationStatus == 0 else {
        let err = String(data: data, encoding: .utf8) ?? ""
        throw SPMExtendedError.commandFailed("Could not read package name (is this a Swift package directory?): \(err)")
    }
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let name = json["name"] as? String else {
        throw SPMExtendedError.commandFailed("Could not parse package name from dump-package output.")
    }
    return name
}

func resolveSwiftPath() -> String {
    let env = ProcessInfo.processInfo.environment
    if let path = env["PATH"] {
        for component in path.split(separator: ":") {
            let candidate = (String(component) as NSString).appendingPathComponent("swift")
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
    }
    return "/usr/bin/swift"
}

func printTopLevelHelp() {
    print("""
    SPM Extended - Registry and dependency tools

    USAGE: spm-extended <command> [options] [--] [command-options]

    COMMANDS:
      registry    Registry operations (publish, metadata, create-signing, clean-cache)
      outdated    List current vs available versions for all dependencies

    GLOBAL OPTIONS (before command):
      --package-path <path>   Package directory (default: current directory)
      --package-name <name>   Package name (default: from Package.swift)
      -h, --help              Show this help

    EXAMPLES:
      spm-extended registry publish myorg.MyPackage 1.0.0 --url https://registry.example.com
      spm-extended registry metadata create
      spm-extended outdated
      spm-extended --package-path /path/to/package registry publish myorg.MyPackage 1.0.0 --url https://registry.example.com

    Install with Mint:
      mint install wgr1984/swift-package-manager-extended-plugin
      spm-extended registry publish ...
    """)
}

main()
