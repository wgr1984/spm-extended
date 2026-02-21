import Foundation
import PackagePlugin

@main
struct RegistryPlugin: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) throws {
        let swiftPath = try context.tool(named: "swift").path.string
        let env = RunEnvironment(
            packageDirectory: context.package.directory.string,
            packageName: context.package.displayName,
            swiftPath: swiftPath
        )
        do {
            try RegistryRunner.run(environment: env, arguments: arguments)
        } catch let error as SPMExtendedError {
            throw PluginError.from(error)
        }
    }
}

enum PluginError: Error, CustomStringConvertible {
    case commandFailed(String)
    case missingArgument(String)
    case invalidArgument(String)
    case unknownSubcommand(String)
    case sandboxRequired(String)

    static func from(_ error: SPMExtendedError) -> PluginError {
        switch error {
        case .commandFailed(let m): return .commandFailed(m)
        case .missingArgument(let m): return .missingArgument(m)
        case .invalidArgument(let m): return .invalidArgument(m)
        case .unknownSubcommand(let m): return .unknownSubcommand(m)
        case .sandboxRequired(let m): return .sandboxRequired(m)
        }
    }

    var description: String {
        switch self {
        case .commandFailed(let m): return "Command failed: \(m)"
        case .missingArgument(let m): return "Missing required argument: \(m)"
        case .invalidArgument(let m): return "Invalid argument: \(m)"
        case .unknownSubcommand(let m): return m
        case .sandboxRequired(let m): return m
        }
    }
}
