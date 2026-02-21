import Foundation

/// Environment for running registry/outdated commands without PackagePlugin.
/// Used by both the CLI and (via adapter) the plugins.
public struct RunEnvironment {
    public let packageDirectory: String
    public let packageName: String
    public let swiftPath: String

    public init(packageDirectory: String, packageName: String, swiftPath: String) {
        self.packageDirectory = packageDirectory
        self.packageName = packageName
        self.swiftPath = swiftPath
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
