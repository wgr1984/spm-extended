import Foundation

/// Helper for detecting sandbox-related errors in the outdated command.
enum SandboxErrorHelper {
    private static let sandboxErrorPatterns = [
        "permission", "sandbox", "operation not permitted",
        "not accessible or not writable", "nsposixerrordomain"
    ]

    static func isSandboxError(_ output: String) -> Bool {
        let outputLower = output.lowercased()
        if outputLower.contains("server error") || outputLower.contains("error 4") || outputLower.contains("error 5") {
            return false
        }
        if outputLower.range(of: "\\berror\\s+\\d{3}\\b|\\b\\d{3}\\s+error", options: .regularExpression) != nil {
            return false
        }
        return sandboxErrorPatterns.contains { outputLower.contains($0) }
    }

    static func outdatedSandboxErrorMessage() -> String {
        """
        ❌ The --disable-sandbox flag is required to check for dependency updates.

        WHY THIS IS NEEDED:
        This command contacts registries and Git remotes to list available versions.
        The plugin sandbox blocks network access, so those requests will fail.

        HOW TO FIX:
        Add the --disable-sandbox flag:

          swift package --disable-sandbox outdated
        """
    }
}
