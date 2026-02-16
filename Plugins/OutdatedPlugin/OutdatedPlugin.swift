import Foundation
import PackagePlugin

@main
struct OutdatedPlugin: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) throws {
        let command = OutdatedCommand(
            context: context,
            packageDirectory: context.package.directory,
            packageName: context.package.displayName
        )
        try command.execute(arguments: arguments)
    }
}

/// Errors used by the outdated command (local to this plugin).
enum PluginError: Error, CustomStringConvertible {
    case commandFailed(String)
    case sandboxRequired(String)

    var description: String {
        switch self {
        case .commandFailed(let message): return "Command failed: \(message)"
        case .sandboxRequired(let message): return message
        }
    }
}
