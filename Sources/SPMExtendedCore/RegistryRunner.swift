import Foundation

/// Public entry point for registry subcommands (used by plugin and CLI).
public enum RegistryRunner {
    public static func run(environment: RunEnvironment, arguments: [String]) throws {
        if arguments.contains("--version") || arguments.contains("-V") {
            print("v\(AppVersion.current)")
            return
        }
        guard let subcommand = arguments.first else {
            print("\(environment.bannerPrefix()) - Registry")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print()
            printHelp()
            return
        }

        let remainingArgs = Array(arguments.dropFirst())

        switch subcommand {
        case "publish":
            try PublishCommand(environment: environment).execute(arguments: remainingArgs)
        case "metadata":
            try MetadataCommand(environment: environment).execute(arguments: remainingArgs)
        case "create-signing":
            try CreateSigningCommand(environment: environment).execute(arguments: remainingArgs)
        case "clean-cache":
            try CleanCacheCommand(environment: environment).execute(arguments: remainingArgs)
        case "list":
            try ListCommand(environment: environment).execute(arguments: remainingArgs)
        case "verify":
            try VerifyCommand(environment: environment).execute(arguments: remainingArgs)
        case "--help", "-h", "help":
            print("\(environment.bannerPrefix()) - Registry")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print()
            printHelp()
        default:
            throw SPMExtendedError.unknownSubcommand("Unknown subcommand: '\(subcommand)'. Available: publish, metadata, create-signing, clean-cache, list, verify")
        }
    }

    private static func printHelp() {
        print("""
        OVERVIEW: Registry operations with automatic Package.json generation

        USAGE: swift package registry <subcommand> [options]

        SUBCOMMANDS:
          publish                 Publish package to registry with Package.json generation
          metadata                Metadata file operations for registry packages
          create-signing          Create package-signing CA and optionally adapt registry settings
          clean-cache             Clean SPM registry caches and fingerprints (--local, --global, --all)
          list                    List available versions for a package
          verify                  Verify release metadata, signing, and manifest for a package version

        OPTIONS:
          -h, --help              Show help information

        SEE ALSO:
          swift package registry publish --help
          swift package registry metadata --help
          swift package registry create-signing --help
          swift package registry clean-cache --help
          swift package registry list --help
          swift package registry verify --help
          swift package outdated --help
        """)
    }
}
