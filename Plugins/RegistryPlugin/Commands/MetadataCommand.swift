import Foundation
import PackagePlugin

struct MetadataCommand {
    let context: PluginContext
    let packageDirectory: Path
    let packageName: String
    
    func execute(arguments: [String]) throws {
        // Check for sub-subcommand
        guard let subSubcommand = arguments.first else {
            print("🚀 SPM Extended Plugin - Registry Metadata")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print()
            printHelp()
            return
        }
        
        // Parse sub-subcommand
        let remainingArgs = Array(arguments.dropFirst())
        
        switch subSubcommand {
        case "create":
            let command = CreateCommand(
                context: context,
                packageDirectory: packageDirectory,
                packageName: packageName
            )
            try command.execute(arguments: remainingArgs)
        case "--help", "-h", "help":
            print("🚀 SPM Extended Plugin - Registry Metadata")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print()
            printHelp()
        default:
            throw PluginError.unknownSubcommand("Unknown metadata subcommand: '\(subSubcommand)'. Available: create")
        }
    }
    
    private func printHelp() {
        print("""
        OVERVIEW: Metadata file operations for registry packages
        
        USAGE: swift package registry metadata <subcommand> [options]
        
        SUBCOMMANDS:
          create                  Create Package.json and package-metadata.json files
        
        OPTIONS:
          -h, --help              Show help information
        
        SEE ALSO:
          swift package registry metadata create --help
        """)
    }
}
