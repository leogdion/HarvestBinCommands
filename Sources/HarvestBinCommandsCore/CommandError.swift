import Foundation

public enum CommandError: Error, LocalizedError, Sendable {
    case validationFailed(String)
    case executionFailed(exitCode: Int32, stderr: String)
    case sudoRequired
    case outputParsingFailed
    case unknownDomain(String)
    case unknownKey(String)
    case typeMismatch(expected: String, actual: String)
    case permissionDenied
    case timeout
    case invalidOutput(String)
    
    public var errorDescription: String? {
        switch self {
        case .validationFailed(let message):
            return "Command validation failed: \(message)"
        case .executionFailed(let exitCode, let stderr):
            return "Command execution failed with exit code \(exitCode): \(stderr)"
        case .sudoRequired:
            return "This command requires sudo privileges"
        case .outputParsingFailed:
            return "Failed to parse command output"
        case .unknownDomain(let domain):
            return "Unknown domain: \(domain)"
        case .unknownKey(let key):
            return "Unknown key: \(key)"
        case .typeMismatch(let expected, let actual):
            return "Type mismatch: expected \(expected), got \(actual)"
        case .permissionDenied:
            return "Permission denied"
        case .timeout:
            return "Command execution timed out"
        case .invalidOutput(let message):
            return "Invalid command output: \(message)"
        }
    }
}