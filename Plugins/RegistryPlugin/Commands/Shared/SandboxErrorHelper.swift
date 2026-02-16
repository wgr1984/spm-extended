import Foundation

/// Helper functions for detecting and formatting sandbox-related errors
enum SandboxErrorHelper {
    /// Error patterns that indicate sandbox restrictions
    private static let sandboxErrorPatterns = [
        "permission",
        "sandbox",
        "operation not permitted",
        "not accessible or not writable",
        "nsposixerrordomain"
    ]
    
    /// Patterns that indicate server/HTTP errors (not sandbox errors)
    private static let serverErrorPatterns = [
        "server error",
        "http error",
        "status code",
        "status:",
        "error 4",
        "error 5"
    ]
    
    /// Check if an error output indicates a sandbox restriction
    /// Returns false if the error appears to be a server/HTTP error (like 409, 400, 500, etc.)
    static func isSandboxError(_ output: String) -> Bool {
        let outputLower = output.lowercased()
        
        // First, check if this is clearly a server/HTTP error - if so, it's not a sandbox error
        if serverErrorPatterns.contains(where: { outputLower.contains($0) }) {
            return false
        }
        
        // Check for HTTP status codes (e.g., "409", "400", "500")
        // These indicate server responses, not sandbox issues
        if outputLower.range(of: "\\berror\\s+\\d{3}\\b|\\b\\d{3}\\s+error|status\\s+\\d{3}", options: .regularExpression) != nil {
            return false
        }
        
        // Now check for actual sandbox-related patterns
        return sandboxErrorPatterns.contains { outputLower.contains($0) }
    }
    
    /// Generate a sandbox error message for publish command
    static func publishSandboxErrorMessage(packageId: String, version: String) -> String {
        """
        ❌ The --disable-sandbox flag is required to publish packages.
        
        WHY THIS IS NEEDED:
        Swift Package Manager plugins run in a sandbox environment by default, which restricts 
        file system access and network operations. Publishing to a registry requires:
        
        • Writing Package.json to the package directory
        • Creating temporary archives and metadata files
        • Making network requests to the registry server
        • Accessing signing keys and certificates (if using signed releases)
        
        These operations are blocked by the sandbox and will cause the publish to fail.
        
        HOW TO FIX:
        Add the --disable-sandbox flag to your command:
        
          swift package --disable-sandbox registry publish \\
            \(packageId) \(version) --url <registry-url>
        
        NOTE: This flag is safe to use for publishing operations and is standard practice 
              for registry workflows that require file system and network access.
        """
    }
    
    /// Generate a sandbox error message for metadata create command
    static func createSandboxErrorMessage() -> String {
        """
        ❌ The --disable-sandbox flag is required to create metadata files.
        
        WHY THIS IS NEEDED:
        Swift Package Manager plugins run in a sandbox environment by default, which restricts 
        file system access. Creating metadata files requires:
        
        • Writing Package.json to the package directory
        • Writing package-metadata.json to the package directory
        • Running swift package dump-package to extract package information
        • Accessing git configuration for author information
        • Reading README and LICENSE files
        
        These operations are blocked by the sandbox and will cause the command to fail.
        
        HOW TO FIX:
        Add the --disable-sandbox flag to your command:
        
          swift package --disable-sandbox registry metadata create
        
        NOTE: This flag is safe to use for metadata creation operations.
        """
    }

    /// Generate a sandbox error message for outdated command
    static func outdatedSandboxErrorMessage() -> String {
        """
        ❌ The --disable-sandbox flag is required to check for dependency updates.

        WHY THIS IS NEEDED:
        This command contacts registries and Git remotes to list available versions.
        The plugin sandbox blocks network access, so those requests will fail.

        HOW TO FIX:
        Add the --disable-sandbox flag:

          swift package --disable-sandbox registry outdated
        """
    }
}
