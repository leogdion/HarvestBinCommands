import Foundation

public struct CommandResult: Sendable {
    public let exitCode: Int32
    public let standardOutput: String
    public let standardError: String
    public let executionTime: TimeInterval
    
    public init(exitCode: Int32, standardOutput: String, standardError: String, executionTime: TimeInterval = 0) {
        self.exitCode = exitCode
        self.standardOutput = standardOutput
        self.standardError = standardError
        self.executionTime = executionTime
    }
    
    public var isSuccess: Bool {
        return exitCode == 0
    }
    
    public var hasOutput: Bool {
        return !standardOutput.isEmpty || !standardError.isEmpty
    }
    
    public var combinedOutput: String {
        var combined = standardOutput
        if !standardError.isEmpty {
            if !combined.isEmpty {
                combined += "\n"
            }
            combined += standardError
        }
        return combined
    }
}