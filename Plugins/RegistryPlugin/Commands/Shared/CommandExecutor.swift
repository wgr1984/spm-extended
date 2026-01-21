import Foundation

/// Helper class for executing shell commands with real-time output streaming and capture
struct CommandExecutor {
    /// Result of command execution
    struct Result {
        let process: Process
        let output: String
        let errorOutput: String
        let exitCode: Int32
        
        var isSuccess: Bool {
            exitCode == 0
        }
    }
    
    /// Detect the shell from environment variables
    /// - Returns: The shell path from SHELL environment variable, or /bin/bash as fallback
    private static func detectShell() -> String {
        if let shell = ProcessInfo.processInfo.environment["SHELL"],
           !shell.isEmpty,
           FileManager.default.fileExists(atPath: shell) {
            return shell
        }
        return "/bin/bash"
    }
    
    /// Execute a shell command with real-time output streaming and capture
    /// - Parameters:
    ///   - command: The shell command to execute
    ///   - workingDirectory: The directory to execute the command in
    ///   - shell: The shell to use (default: detected from environment or /bin/bash)
    /// - Returns: Result containing the process, captured output, and exit code
    /// - Throws: Error if the process cannot be started
    static func execute(
        command: String,
        workingDirectory: String,
        shell: String = detectShell()
    ) throws -> Result {
        let outputPipe = Pipe()
        var capturedOutput = Data()
        let outputHandle = outputPipe.fileHandleForReading
        
        // Read output in background and print in real-time
        outputHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                capturedOutput.append(data)
                if let string = String(data: data, encoding: .utf8) {
                    print(string, terminator: "")
                }
            }
        }
        
        // Execute the command
        let task = Process()
        task.executableURL = URL(fileURLWithPath: shell)
        task.arguments = ["-c", "set -o pipefail && cd \"\(workingDirectory)\" && \(command) 2>&1"]
        task.standardOutput = outputPipe
        task.standardError = outputPipe
        
        try task.run()
        task.waitUntilExit()
        
        // Close the pipe and get final output
        outputHandle.readabilityHandler = nil
        outputHandle.closeFile()
        
        let output = String(data: capturedOutput, encoding: .utf8) ?? ""
        
        return Result(
            process: task,
            output: output,
            errorOutput: output, // For shell commands, stderr is merged with stdout
            exitCode: task.terminationStatus
        )
    }
    
    /// Execute a direct process (not via shell) with timeout support and output capture
    /// - Parameters:
    ///   - executable: Path to the executable
    ///   - arguments: Command arguments
    ///   - workingDirectory: The directory to execute the command in
    ///   - timeout: Maximum time to wait (in seconds). If nil, waits indefinitely.
    ///   - verbose: Whether to print verbose information
    /// - Returns: Result containing the process, captured output, and exit code
    /// - Throws: Error if the process cannot be started or times out
    static func executeProcess(
        executable: String,
        arguments: [String],
        workingDirectory: String,
        timeout: TimeInterval? = nil,
        verbose: Bool = false
    ) throws -> Result {
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = arguments
        task.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        
        if verbose {
            let commandLine = ([executable] + arguments).joined(separator: " ")
            print("   Executing: \(commandLine)")
        }
        
        try task.run()
        
        // Wait with optional timeout
        if let timeout = timeout {
            let startTime = Date()
            while task.isRunning {
                if Date().timeIntervalSince(startTime) > timeout {
                    task.terminate()
                    throw PluginError.commandFailed("Command timed out after \(Int(timeout)) seconds")
                }
                Thread.sleep(forTimeInterval: 0.1)
            }
        } else {
            task.waitUntilExit()
        }
        
        // Read the output
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
        
        return Result(
            process: task,
            output: output,
            errorOutput: errorOutput,
            exitCode: task.terminationStatus
        )
    }
}
