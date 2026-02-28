import Foundation
import PackagePlugin

@main
struct OutdatedPlugin: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) throws {
        let swiftPath = try context.tool(named: "swift").path.string
        let env = RunEnvironment(
            packageDirectory: context.package.directory.string,
            packageName: context.package.displayName,
            swiftPath: swiftPath,
            invocationSource: .plugin
        )
        do {
            try OutdatedRunner.run(environment: env, arguments: arguments)
        } catch let error as SPMExtendedError {
            throw PluginError.from(error)
        }
    }
}

enum PluginError: Error, CustomStringConvertible {
    case commandFailed(String)
    case sandboxRequired(String)

    static func from(_ error: SPMExtendedError) -> PluginError {
        switch error {
        case .commandFailed(let m): return .commandFailed(m)
        case .sandboxRequired(let m): return .sandboxRequired(m)
        case .missingArgument(let m): return .commandFailed(m)
        case .invalidArgument(let m): return .commandFailed(m)
        case .unknownSubcommand(let m): return .commandFailed(m)
        }
    }

    var description: String {
        switch self {
        case .commandFailed(let m): return "Command failed: \(m)"
        case .sandboxRequired(let m): return m
        }
    }
}
