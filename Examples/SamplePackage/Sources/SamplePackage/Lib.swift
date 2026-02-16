import DemoLib
import Numerics

/// A trivial type for the sample package.
public struct SampleLibrary {
    public init() {}

    /// Returns a greeting string.
    public func greet() -> String {
        "\(demoGreeting()) + SamplePackage"
    }

    /// Trivial use of Numerics so the dependency is not unused.
    public static func identity<T: Real>(_ x: T) -> T { x }
}
