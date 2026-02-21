import Foundation

/// Shared error type for core commands (CLI and plugin adapters).
public enum SPMExtendedError: Error, CustomStringConvertible {
    case commandFailed(String)
    case missingArgument(String)
    case invalidArgument(String)
    case unknownSubcommand(String)
    case sandboxRequired(String)

    public var description: String {
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
