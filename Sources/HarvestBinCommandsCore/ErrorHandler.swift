import Foundation

public struct ErrorHandler {
    
    public static func mapSubprocessError(_ error: Error, command: CommandProtocol, exitCode: Int32? = nil) -> CommandError {
        // Map subprocess errors to CommandError cases
        if let commandError = error as? CommandError {
            return commandError
        }
        
        let errorDescription = error.localizedDescription.lowercased()
        
        // Check for common error patterns
        if errorDescription.contains("permission denied") || exitCode == 126 {
            return .permissionDenied
        }
        
        if errorDescription.contains("command not found") || exitCode == 127 {
            return .validationFailed("Command '\(command.command)' not found. Ensure it's installed and in PATH.")
        }
        
        if errorDescription.contains("timeout") || errorDescription.contains("timed out") {
            return .timeout
        }
        
        if errorDescription.contains("network") || errorDescription.contains("connection") {
            return .executionFailed(exitCode: exitCode ?? -1, stderr: "Network error: \(error.localizedDescription)")
        }
        
        // Map common exit codes
        if let code = exitCode {
            return mapExitCodeToError(code, command: command, originalError: error.localizedDescription)
        }
        
        return .executionFailed(exitCode: -1, stderr: error.localizedDescription)
    }
    
    public static func mapExitCodeToError(_ exitCode: Int32, command: CommandProtocol, originalError: String) -> CommandError {
        switch exitCode {
        case 0:
            return .validationFailed("Unexpected success exit code in error context")
        case 1:
            return .executionFailed(exitCode: exitCode, stderr: "General error: \(originalError)")
        case 2:
            return .validationFailed("Misuse of shell builtin or invalid arguments")
        case 126:
            return .permissionDenied
        case 127:
            return .validationFailed("Command '\(command.command)' not found")
        case 128...165:
            let signal = exitCode - 128
            return .executionFailed(exitCode: exitCode, stderr: "Process terminated by signal \(signal): \(originalError)")
        default:
            return .executionFailed(exitCode: exitCode, stderr: originalError)
        }
    }
    
    public static func getRecoverySuggestions(for error: CommandError) -> [String] {
        switch error {
        case .validationFailed(let message):
            if message.contains("not found") {
                return [
                    "Install the required command using Homebrew, MacPorts, or the system package manager",
                    "Check that the command is in your PATH environment variable",
                    "Verify the command name spelling"
                ]
            } else if message.contains("invalid arguments") {
                return [
                    "Check the command syntax and arguments",
                    "Refer to the command's manual page (man command)",
                    "Ensure all required parameters are provided"
                ]
            }
            return ["Review the validation error and correct the input"]
            
        case .executionFailed(_, let stderr):
            var suggestions = ["Check the command output for specific error details"]
            
            if stderr.contains("permission denied") {
                suggestions.append("Try running with elevated privileges (sudo)")
                suggestions.append("Check file and directory permissions")
            }
            
            if stderr.contains("file not found") || stderr.contains("no such file") {
                suggestions.append("Verify that the target file or directory exists")
                suggestions.append("Check the file path for typos")
            }
            
            if stderr.contains("network") || stderr.contains("connection") {
                suggestions.append("Check your internet connection")
                suggestions.append("Verify network settings and firewall configuration")
                suggestions.append("Try again after a short delay")
            }
            
            return suggestions
            
        case .sudoRequired:
            return [
                "Run the command with sudo privileges",
                "Ensure your user account has sudo access",
                "Check sudoers configuration if needed"
            ]
            
        case .permissionDenied:
            return [
                "Check file and directory permissions",
                "Run with appropriate user privileges",
                "Use sudo if elevated privileges are required"
            ]
            
        case .timeout:
            return [
                "Increase the command timeout value",
                "Check if the process is hanging or waiting for input",
                "Ensure sufficient system resources are available"
            ]
            
        case .outputParsingFailed:
            return [
                "Verify the command produces expected output format",
                "Check for malformed or incomplete output",
                "Ensure proper encoding (UTF-8) is used"
            ]
            
        case .unknownDomain(let domain):
            return [
                "Verify the domain '\(domain)' is correct",
                "Check available domains with 'defaults domains'"
            ]
            
        case .unknownKey(let key):
            return [
                "Verify the key '\(key)' exists in the specified domain",
                "List available keys to find the correct one"
            ]
            
        case .typeMismatch(let expected, let actual):
            return [
                "Convert the value to the expected type: \(expected)",
                "Check the current type: \(actual)",
                "Use appropriate type conversion utilities"
            ]
            
        case .invalidOutput(_):
            return [
                "Check the command output format",
                "Verify the command executed successfully",
                "Review any parsing or formatting requirements"
            ]
        }
    }
    
    public static func createDetailedError(_ error: CommandError, context: ErrorContext) -> DetailedError {
        let suggestions = getRecoverySuggestions(for: error)
        return DetailedError(
            originalError: error,
            context: context,
            recoverySuggestions: suggestions,
            timestamp: Date()
        )
    }
    
    public static func logError(_ error: CommandError, context: ErrorContext) {
        let detailedError = createDetailedError(error, context: context)
        
        // For now, use print for logging. In a real implementation, this could use os_log or other logging frameworks
        print("🔴 Command Error: \(error.errorDescription ?? "Unknown error")")
        print("📍 Context: Command '\(context.command)' with args: \(context.arguments)")
        print("💡 Suggestions:")
        for suggestion in detailedError.recoverySuggestions {
            print("  • \(suggestion)")
        }
    }
}

public struct ErrorContext {
    public let command: String
    public let arguments: [String]
    public let workingDirectory: String?
    public let environment: [String: String]?
    
    public init(command: String, arguments: [String], workingDirectory: String? = nil, environment: [String: String]? = nil) {
        self.command = command
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.environment = environment
    }
}

public struct DetailedError {
    public let originalError: CommandError
    public let context: ErrorContext
    public let recoverySuggestions: [String]
    public let timestamp: Date
    
    public var formattedDescription: String {
        var description = "Error: \(originalError.errorDescription ?? "Unknown error")\n"
        description += "Command: \(context.command) \(context.arguments.joined(separator: " "))\n"
        
        if let workingDir = context.workingDirectory {
            description += "Working Directory: \(workingDir)\n"
        }
        
        description += "Timestamp: \(timestamp)\n"
        description += "Recovery Suggestions:\n"
        
        for (index, suggestion) in recoverySuggestions.enumerated() {
            description += "\(index + 1). \(suggestion)\n"
        }
        
        return description
    }
}