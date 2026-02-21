import Foundation

/// Public entry point for outdated command (used by plugin and CLI).
public enum OutdatedRunner {
    public static func run(environment: RunEnvironment, arguments: [String]) throws {
        try OutdatedCommand(environment: environment).execute(arguments: arguments)
    }
}
