import Foundation

public actor CommandExecutor {
    public static let shared = CommandExecutor()
    
    private init() {}
    
    public func execute(_ command: CommandProtocol, timeout: TimeInterval = 30.0) async throws -> CommandResult {
        try command.validate()
        try PrivilegeEscalation.validateSudoCommand(command)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let executable: String
        let args: [String]
        
        if command.requiresSudo {
            executable = "sudo"
            args = [command.command] + command.arguments
        } else {
            executable = command.command
            args = command.arguments
        }
        
        do {
            let result = try await executeProcess(executable: executable, arguments: args, timeout: timeout)
            let executionTime = CFAbsoluteTimeGetCurrent() - startTime
            
            if let processToKill = command.affectedProcess {
                try await ProcessKiller.killProcess(processToKill)
            }
            
            let finalResult = CommandResult(
                exitCode: result.exitCode,
                standardOutput: result.standardOutput,
                standardError: result.standardError,
                executionTime: executionTime
            )
            
            if !finalResult.isSuccess {
                throw CommandError.executionFailed(exitCode: result.exitCode, stderr: result.standardError)
            }
            
            return finalResult
            
        } catch let error as CommandError {
            let context = ErrorContext(command: command.command, arguments: command.arguments)
            ErrorHandler.logError(error, context: context)
            throw error
        } catch {
            let context = ErrorContext(command: command.command, arguments: command.arguments)
            let mappedError = ErrorHandler.mapSubprocessError(error, command: command)
            ErrorHandler.logError(mappedError, context: context)
            throw mappedError
        }
    }
    
    private func executeProcess(executable: String, arguments: [String], timeout: TimeInterval) async throws -> (exitCode: Int32, standardOutput: String, standardError: String) {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        return try await withThrowingTaskGroup(of: ProcessResult.self) { group in
            // Add the main process task
            group.addTask {
                return try await withCheckedThrowingContinuation { continuation in
                    process.terminationHandler = { process in
                        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                        
                        let stdout = String(data: outputData, encoding: .utf8) ?? ""
                        let stderr = String(data: errorData, encoding: .utf8) ?? ""
                        
                        continuation.resume(returning: ProcessResult(
                            exitCode: process.terminationStatus,
                            standardOutput: stdout,
                            standardError: stderr,
                            isTimeout: false
                        ))
                    }
                    
                    do {
                        try process.run()
                    } catch {
                        continuation.resume(throwing: ErrorHandler.mapSubprocessError(error, command: MockCommand(command: executable, arguments: arguments)))
                    }
                }
            }
            
            // Add timeout task if needed
            if timeout > 0 {
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    
                    if process.isRunning {
                        process.terminate()
                        
                        // If terminate doesn't work, send SIGKILL after 1 second
                        try await Task.sleep(nanoseconds: 1_000_000_000)
                        if process.isRunning {
                            kill(process.processIdentifier, SIGKILL)
                        }
                    }
                    
                    return ProcessResult(exitCode: -1, standardOutput: "", standardError: "Process timed out", isTimeout: true)
                }
            }
            
            // Wait for the first task to complete
            for try await result in group {
                group.cancelAll() // Cancel any remaining tasks
                
                if result.isTimeout {
                    throw CommandError.timeout
                } else {
                    return (exitCode: result.exitCode, standardOutput: result.standardOutput, standardError: result.standardError)
                }
            }
            
            throw CommandError.executionFailed(exitCode: -1, stderr: "Process execution failed")
        }
    }
}

private struct ProcessResult: Sendable {
    let exitCode: Int32
    let standardOutput: String
    let standardError: String
    let isTimeout: Bool
}

// Helper for error mapping
private struct MockCommand: CommandProtocol {
    let command: String
    let arguments: [String]
    let requiresSudo: Bool = false
    let affectedProcess: String? = nil
    
    func validate() throws {
        // No validation needed for error mapping helper
    }
}