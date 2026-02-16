import Foundation

/// Helper for executing shell commands (used by outdated command for git ls-remote).
struct CommandExecutor {
    struct Result {
        let process: Process
        let output: String
        let errorOutput: String
        let exitCode: Int32
        var isSuccess: Bool { exitCode == 0 }
    }

    private static func detectShell() -> String {
        if let shell = ProcessInfo.processInfo.environment["SHELL"],
           !shell.isEmpty,
           FileManager.default.fileExists(atPath: shell) {
            return shell
        }
        return "/bin/bash"
    }

    static func execute(
        command: String,
        workingDirectory: String,
        shell: String = detectShell()
    ) throws -> Result {
        let outputPipe = Pipe()
        var capturedOutput = Data()
        let outputHandle = outputPipe.fileHandleForReading
        outputHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                capturedOutput.append(data)
                if let string = String(data: data, encoding: .utf8) { print(string, terminator: "") }
            }
        }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: shell)
        task.arguments = ["-c", "set -o pipefail && cd \"\(workingDirectory)\" && \(command) 2>&1"]
        task.standardOutput = outputPipe
        task.standardError = outputPipe
        try task.run()
        task.waitUntilExit()
        outputHandle.readabilityHandler = nil
        outputHandle.closeFile()
        let output = String(data: capturedOutput, encoding: .utf8) ?? ""
        return Result(process: task, output: output, errorOutput: output, exitCode: task.terminationStatus)
    }
}
