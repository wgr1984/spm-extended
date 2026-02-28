import Foundation

/// How the command was invoked (plugin vs standalone CLI).
public enum InvocationSource {
    case plugin
    case standalone
}

/// Environment for running registry/outdated commands without PackagePlugin.
/// Used by both the CLI and (via adapter) the plugins.
public struct RunEnvironment {
    public let packageDirectory: String
    public let packageName: String
    public let swiftPath: String
    public let invocationSource: InvocationSource

    public init(packageDirectory: String, packageName: String, swiftPath: String, invocationSource: InvocationSource = .standalone) {
        self.packageDirectory = packageDirectory
        self.packageName = packageName
        self.swiftPath = swiftPath
        self.invocationSource = invocationSource
    }

    /// Banner prefix for command output (differentiates plugin vs standalone).
    public func bannerPrefix() -> String {
        switch invocationSource {
        case .plugin: return "🚀 SPM Extended Plugin"
        case .standalone: return "🚀 SPM Extended"
        }
    }

    /// Path to a file/dir under the package directory.
    public func path(components: String...) -> String {
        var result = packageDirectory
        for comp in components {
            result = (result as NSString).appendingPathComponent(comp)
        }
        return result
    }
}
