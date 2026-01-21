import Foundation

/// Helper functions for detecting and formatting sandbox-related errors
enum SandboxErrorHelper {
    /// Error patterns that indicate sandbox restrictions
    private static let sandboxErrorPatterns = [
        "permission",
        "sandbox",
        "operation not permitted",
        "not accessible or not writable",
        "nsposixerrordomain",
        "failed publishing",
        "error: failed publishing"
    ]
    
    /// Check if an error output indicates a sandbox restriction
    static func isSandboxError(_ output: String) -> Bool {
        let outputLower = output.lowercased()
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
}
