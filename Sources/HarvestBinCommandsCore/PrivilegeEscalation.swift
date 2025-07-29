import Foundation

public struct PrivilegeEscalation {
    
    public static func validateSudoCommand(_ command: CommandProtocol) throws {
        guard command.requiresSudo else { return }
        
        // Prevent command injection by validating command structure
        let suspiciousPatterns = [";", "&", "|", "&&", "||", "`", "$", "$(", "${"]
        
        for pattern in suspiciousPatterns {
            if command.command.contains(pattern) {
                throw CommandError.validationFailed("Command contains potentially unsafe pattern: \(pattern)")
            }
            
            for arg in command.arguments {
                if arg.contains(pattern) {
                    throw CommandError.validationFailed("Argument contains potentially unsafe pattern: \(pattern)")
                }
            }
        }
        
        // Validate that the command is not trying to execute privileged operations inappropriately
        let dangerousCommands = ["rm", "format", "dd", "chmod", "chown"]
        if dangerousCommands.contains(command.command) {
            // Allow but add extra validation for dangerous commands
            try validateDangerousCommand(command)
        }
    }
    
    public static func checkSudoAvailability() async throws -> Bool {
        do {
            let result = try await CommandExecutor.shared.execute(SudoCheckCommand())
            return result.isSuccess
        } catch {
            return false
        }
    }
    
    private static func validateDangerousCommand(_ command: CommandProtocol) throws {
        // Add specific validations for dangerous commands
        switch command.command {
        case "rm":
            // Prevent recursive deletion of system directories
            let systemPaths = ["/", "/usr", "/bin", "/sbin", "/etc", "/var", "/System"]
            for arg in command.arguments {
                for path in systemPaths {
                    if arg.hasPrefix(path) && !arg.hasPrefix("/var/folders") {
                        throw CommandError.validationFailed("Refusing to delete system path: \(arg)")
                    }
                }
            }
        case "chmod", "chown":
            // Prevent modification of system files
            let systemPaths = ["/bin", "/sbin", "/usr/bin", "/usr/sbin", "/System"]
            for arg in command.arguments {
                for path in systemPaths {
                    if arg.hasPrefix(path) {
                        throw CommandError.validationFailed("Refusing to modify system path: \(arg)")
                    }
                }
            }
        default:
            break
        }
    }
}

private struct SudoCheckCommand: CommandProtocol {
    var command: String { "sudo" }
    var arguments: [String] { ["-n", "true"] }
    var requiresSudo: Bool { false }
    var affectedProcess: String? { nil }
    
    func validate() throws {
        // No validation needed for sudo check
    }
}