import Foundation

struct MetadataCommand {
    let environment: RunEnvironment

    func execute(arguments: [String]) throws {
        guard let subSubcommand = arguments.first else {
            print("🚀 SPM Extended Plugin - Registry Metadata")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print()
            printHelp()
            return
        }

        let remainingArgs = Array(arguments.dropFirst())

        switch subSubcommand {
        case "create":
            let command = CreateCommand(environment: environment)
            try command.execute(arguments: remainingArgs)
        case "--help", "-h", "help":
            print("🚀 SPM Extended Plugin - Registry Metadata")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print()
            printHelp()
        default:
            throw SPMExtendedError.unknownSubcommand("Unknown metadata subcommand: '\(subSubcommand)'. Available: create")
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
