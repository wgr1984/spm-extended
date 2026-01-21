import Foundation
import PackagePlugin

@main
struct RegistryPlugin: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) throws {
        let packageDirectory = context.package.directory
        let packageName = context.package.displayName
        
        // Check for subcommand
        guard let subcommand = arguments.first else {
            print("🚀 SPM Extended Plugin - Registry")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print()
            printHelp()
            return
        }
        
        // Parse subcommand
        let remainingArgs = Array(arguments.dropFirst())
        
        switch subcommand {
        case "publish":
            let command = PublishCommand(
                context: context,
                packageDirectory: packageDirectory,
                packageName: packageName
            )
            try command.execute(arguments: remainingArgs)
        case "metadata":
            let command = MetadataCommand(
                context: context,
                packageDirectory: packageDirectory,
                packageName: packageName
            )
            try command.execute(arguments: remainingArgs)
        case "--help", "-h", "help":
            print("🚀 SPM Extended Plugin - Registry")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print()
            printHelp()
        default:
            throw PluginError.unknownSubcommand("Unknown subcommand: '\(subcommand)'. Available: publish, metadata")
        }
    }
    
    private func printHelp() {
        print("""
        OVERVIEW: Registry operations with automatic Package.json generation
        
        USAGE: swift package registry <subcommand> [options]
        
        SUBCOMMANDS:
          publish                 Publish package to registry with Package.json generation
          metadata                Metadata file operations for registry packages
        
        OPTIONS:
          -h, --help              Show help information
        
        SEE ALSO:
          swift package registry publish --help
          swift package registry metadata --help
        """)
    }
}

enum PluginError: Error, CustomStringConvertible {
    case commandFailed(String)
    case missingArgument(String)
    case invalidArgument(String)
    case unknownSubcommand(String)
    case sandboxRequired(String)
    
    var description: String {
        switch self {
        case .commandFailed(let message):
            return "Command failed: \(message)"
        case .missingArgument(let message):
            return "Missing required argument: \(message)"
        case .invalidArgument(let message):
            return "Invalid argument: \(message)"
        case .unknownSubcommand(let message):
            return message
        case .sandboxRequired(let message):
            return message
        }
    }
}
