import Foundation

public struct ProcessKiller {
    
    public enum Signal: String, CaseIterable, Sendable {
        case term = "TERM"
        case kill = "KILL"
        case int = "INT"
        case quit = "QUIT"
        
        var flag: String {
            return "-\(rawValue)"
        }
    }
    
    public static func killProcess(_ processName: String, signal: Signal = .term, delay: TimeInterval = 2.0) async throws {
        // Validate process name to prevent command injection
        try validateProcessName(processName)
        
        // Allow time for graceful shutdown
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        // First try with specified signal (usually TERM for graceful shutdown)
        let success = try await attemptKill(processName: processName, signal: signal)
        
        // If graceful shutdown didn't work and we used TERM, try KILL as fallback
        if !success && signal == .term {
            try await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second
            _ = try await attemptKill(processName: processName, signal: .kill)
        }
    }
    
    public static func killProcessById(_ pid: Int, signal: Signal = .term) async throws {
        guard pid > 0 else {
            throw CommandError.validationFailed("Invalid process ID: \(pid)")
        }
        
        let killCommand = KillByPIDCommand(pid: pid, signal: signal)
        _ = try await CommandExecutor.shared.execute(killCommand)
    }
    
    public static func isProcessRunning(_ processName: String) async throws -> Bool {
        try validateProcessName(processName)
        
        let checkCommand = ProcessCheckCommand(processName: processName)
        let result = try await CommandExecutor.shared.execute(checkCommand)
        
        return result.isSuccess && !result.standardOutput.isEmpty
    }
    
    public static func getProcessPID(_ processName: String) async throws -> [Int] {
        try validateProcessName(processName)
        
        let pidCommand = ProcessPIDCommand(processName: processName)
        let result = try await CommandExecutor.shared.execute(pidCommand)
        
        guard result.isSuccess else { return [] }
        
        let pids = OutputParser.parseLines(result.standardOutput)
            .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        
        return pids
    }
    
    private static func attemptKill(processName: String, signal: Signal) async throws -> Bool {
        let killCommand = KillProcessCommand(processName: processName, signal: signal)
        
        do {
            let result = try await CommandExecutor.shared.execute(killCommand)
            return result.isSuccess
        } catch CommandError.executionFailed(let exitCode, _) {
            // Exit code 1 usually means no matching processes found
            return exitCode == 1
        }
    }
    
    private static func validateProcessName(_ processName: String) throws {
        guard !processName.isEmpty else {
            throw CommandError.validationFailed("Process name cannot be empty")
        }
        
        // Prevent command injection
        let dangerousCharacters = [";", "&", "|", "`", "$", "(", ")", "<", ">", "\"", "'"]
        for char in dangerousCharacters {
            if processName.contains(char) {
                throw CommandError.validationFailed("Process name contains invalid character: \(char)")
            }
        }
        
        // Prevent killing critical system processes
        let protectedProcesses = ["kernel", "launchd", "init", "systemd", "kernel_task"]
        if protectedProcesses.contains(processName.lowercased()) {
            throw CommandError.validationFailed("Cannot kill protected system process: \(processName)")
        }
    }
}

// MARK: - Command Implementations

private struct KillProcessCommand: CommandProtocol {
    let processName: String
    let signal: ProcessKiller.Signal
    
    var command: String { "pkill" }
    var arguments: [String] { [signal.flag, "-f", processName] }
    var requiresSudo: Bool { false }
    var affectedProcess: String? { nil }
    
    func validate() throws {
        if processName.isEmpty {
            throw CommandError.validationFailed("Process name cannot be empty")
        }
    }
}

private struct KillByPIDCommand: CommandProtocol {
    let pid: Int
    let signal: ProcessKiller.Signal
    
    var command: String { "kill" }
    var arguments: [String] { [signal.flag, String(pid)] }
    var requiresSudo: Bool { false }
    var affectedProcess: String? { nil }
    
    func validate() throws {
        if pid <= 0 {
            throw CommandError.validationFailed("Invalid process ID: \(pid)")
        }
    }
}

private struct ProcessCheckCommand: CommandProtocol {
    let processName: String
    
    var command: String { "pgrep" }
    var arguments: [String] { ["-f", processName] }
    var requiresSudo: Bool { false }
    var affectedProcess: String? { nil }
    
    func validate() throws {
        if processName.isEmpty {
            throw CommandError.validationFailed("Process name cannot be empty")
        }
    }
}

private struct ProcessPIDCommand: CommandProtocol {
    let processName: String
    
    var command: String { "pgrep" }
    var arguments: [String] { ["-f", processName] }
    var requiresSudo: Bool { false }
    var affectedProcess: String? { nil }
    
    func validate() throws {
        if processName.isEmpty {
            throw CommandError.validationFailed("Process name cannot be empty")
        }
    }
}