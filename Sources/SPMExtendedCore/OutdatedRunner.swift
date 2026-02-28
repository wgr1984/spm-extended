import Foundation

/// Public entry point for outdated command (used by plugin and CLI).
public enum OutdatedRunner {
    public static func run(environment: RunEnvironment, arguments: [String]) throws {
        if arguments.contains("--version") || arguments.contains("-V") {
            print("v\(AppVersion.current)")
            return
        }
        try OutdatedCommand(environment: environment).execute(arguments: arguments)
    }
}
