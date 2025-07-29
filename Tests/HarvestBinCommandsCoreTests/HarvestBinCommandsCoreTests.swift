import XCTest
@testable import HarvestBinCommandsCore

final class HarvestBinCommandsCoreTests: XCTestCase {
    
    // MARK: - CommandResult Tests
    
    func testCommandResultSuccess() {
        let result = CommandResult(exitCode: 0, standardOutput: "success", standardError: "")
        
        XCTAssertTrue(result.isSuccess)
        XCTAssertTrue(result.hasOutput)
        XCTAssertEqual(result.combinedOutput, "success")
    }
    
    func testCommandResultFailure() {
        let result = CommandResult(exitCode: 1, standardOutput: "", standardError: "error")
        
        XCTAssertFalse(result.isSuccess)
        XCTAssertTrue(result.hasOutput)
        XCTAssertEqual(result.combinedOutput, "error")
    }
    
    func testCommandResultCombinedOutput() {
        let result = CommandResult(exitCode: 0, standardOutput: "stdout", standardError: "stderr")
        
        XCTAssertEqual(result.combinedOutput, "stdout\nstderr")
    }
    
    func testCommandResultNoOutput() {
        let result = CommandResult(exitCode: 0, standardOutput: "", standardError: "")
        
        XCTAssertFalse(result.hasOutput)
        XCTAssertEqual(result.combinedOutput, "")
    }
    
    // MARK: - CommandError Tests
    
    func testCommandErrorDescriptions() {
        XCTAssertEqual(
            CommandError.validationFailed("test").errorDescription,
            "Command validation failed: test"
        )
        
        XCTAssertEqual(
            CommandError.executionFailed(exitCode: 1, stderr: "error").errorDescription,
            "Command execution failed with exit code 1: error"
        )
        
        XCTAssertEqual(CommandError.sudoRequired.errorDescription, "This command requires sudo privileges")
        XCTAssertEqual(CommandError.outputParsingFailed.errorDescription, "Failed to parse command output")
        XCTAssertEqual(CommandError.permissionDenied.errorDescription, "Permission denied")
        XCTAssertEqual(CommandError.timeout.errorDescription, "Command execution timed out")
    }
    
    // MARK: - MockCommand for Testing
    
    struct MockCommand: CommandProtocol {
        let command: String
        let arguments: [String]
        let requiresSudo: Bool
        let affectedProcess: String?
        let shouldFailValidation: Bool
        
        init(command: String = "echo", 
             arguments: [String] = ["test"],
             requiresSudo: Bool = false,
             affectedProcess: String? = nil,
             shouldFailValidation: Bool = false) {
            self.command = command
            self.arguments = arguments
            self.requiresSudo = requiresSudo
            self.affectedProcess = affectedProcess
            self.shouldFailValidation = shouldFailValidation
        }
        
        func validate() throws {
            if shouldFailValidation {
                throw CommandError.validationFailed("Mock validation failure")
            }
        }
    }
    
    // MARK: - PrivilegeEscalation Tests
    
    func testPrivilegeEscalationValidCommand() throws {
        let command = MockCommand(requiresSudo: true)
        XCTAssertNoThrow(try PrivilegeEscalation.validateSudoCommand(command))
    }
    
    func testPrivilegeEscalationCommandInjection() {
        let dangerousCommand = MockCommand(command: "rm; cat /etc/passwd", requiresSudo: true)
        
        XCTAssertThrowsError(try PrivilegeEscalation.validateSudoCommand(dangerousCommand)) { error in
            guard case CommandError.validationFailed(let message) = error else {
                XCTFail("Expected validationFailed error")
                return
            }
            XCTAssertTrue(message.contains("unsafe pattern"))
        }
    }
    
    func testPrivilegeEscalationDangerousArguments() {
        let dangerousCommand = MockCommand(arguments: ["test", "&& rm -rf /"], requiresSudo: true)
        
        XCTAssertThrowsError(try PrivilegeEscalation.validateSudoCommand(dangerousCommand)) { error in
            guard case CommandError.validationFailed(let message) = error else {
                XCTFail("Expected validationFailed error")
                return
            }
            XCTAssertTrue(message.contains("unsafe pattern"))
        }
    }
    
    func testPrivilegeEscalationSystemPathProtection() {
        let dangerousCommand = MockCommand(command: "rm", arguments: ["-rf", "/usr"], requiresSudo: true)
        
        XCTAssertThrowsError(try PrivilegeEscalation.validateSudoCommand(dangerousCommand)) { error in
            guard case CommandError.validationFailed(let message) = error else {
                XCTFail("Expected validationFailed error")
                return
            }
            XCTAssertTrue(message.contains("system path"))
        }
    }
    
    // MARK: - OutputParser Tests
    
    func testOutputParserCleanOutput() {
        let dirtyOutput = "  \u{001B}[31mRed Text\u{001B}[0m  \r\n"
        let cleaned = OutputParser.cleanOutput(dirtyOutput)
        
        XCTAssertEqual(cleaned, "Red Text")
    }
    
    func testOutputParserKeyValuePairs() {
        let output = "key1=value1\nkey2=value2\nempty=\n"
        let pairs = OutputParser.parseKeyValuePairs(output)
        
        XCTAssertEqual(pairs["key1"], "value1")
        XCTAssertEqual(pairs["key2"], "value2")
        XCTAssertEqual(pairs["empty"], "")
        XCTAssertEqual(pairs.count, 3)
    }
    
    func testOutputParserLines() {
        let output = "line1\n\nline2\n  line3  \n"
        let lines = OutputParser.parseLines(output, skipEmpty: true)
        
        XCTAssertEqual(lines, ["line1", "line2", "line3"])
    }
    
    func testOutputParserLinesIncludingEmpty() {
        let output = "line1\n\nline2\n"
        let lines = OutputParser.parseLines(output, skipEmpty: false)
        
        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines[0], "line1")
        XCTAssertEqual(lines[1], "")
        XCTAssertEqual(lines[2], "line2")
    }
    
    func testOutputParserColumnarOutput() {
        let output = "Name    Age    City\nAlice   30     NYC\nBob     25     LA"
        let columns = OutputParser.parseColumnarOutput(output, headerLine: 0)
        
        XCTAssertEqual(columns.count, 2)
        XCTAssertEqual(columns[0], ["Alice", "30", "NYC"])
        XCTAssertEqual(columns[1], ["Bob", "25", "LA"])
    }
    
    func testOutputParserJSONParsing() {
        struct TestData: Codable, Equatable {
            let name: String
            let value: Int
        }
        
        let jsonOutput = """
        {
            "name": "test",
            "value": 42
        }
        """
        
        XCTAssertNoThrow {
            let parsed = try OutputParser.parseJSON(jsonOutput, as: TestData.self)
            XCTAssertEqual(parsed.name, "test")
            XCTAssertEqual(parsed.value, 42)
        }
    }
    
    func testOutputParserInvalidJSON() {
        let invalidJSON = "{ invalid json }"
        
        XCTAssertThrowsError(try OutputParser.parseJSON(invalidJSON, as: [String: String].self)) { error in
            XCTAssertTrue(error is CommandError)
            if case CommandError.outputParsingFailed = error {
                // Expected error
            } else {
                XCTFail("Expected outputParsingFailed error")
            }
        }
    }
    
    func testOutputParserExtractValue() {
        let output = "debug=1\nverbose=true\nname=test app"
        
        XCTAssertEqual(OutputParser.extractValue(from: output, key: "debug"), "1")
        XCTAssertEqual(OutputParser.extractValue(from: output, key: "verbose"), "true")
        XCTAssertEqual(OutputParser.extractValue(from: output, key: "name"), "test app")
        XCTAssertNil(OutputParser.extractValue(from: output, key: "missing"))
    }
    
    // MARK: - ProcessKiller Tests
    
    func testProcessKillerValidation() async {
        await XCTAssertThrowsErrorAsync(try await ProcessKiller.killProcess("")) { error in
            guard case CommandError.validationFailed(let message) = error else {
                XCTFail("Expected validationFailed error")
                return
            }
            XCTAssertTrue(message.contains("cannot be empty"))
        }
    }
    
    func testProcessKillerDangerousCharacters() async {
        await XCTAssertThrowsErrorAsync(try await ProcessKiller.killProcess("test;rm -rf /")) { error in
            guard case CommandError.validationFailed(let message) = error else {
                XCTFail("Expected validationFailed error")
                return
            }
            XCTAssertTrue(message.contains("invalid character"))
        }
    }
    
    func testProcessKillerProtectedProcesses() async {
        await XCTAssertThrowsErrorAsync(try await ProcessKiller.killProcess("kernel")) { error in
            guard case CommandError.validationFailed(let message) = error else {
                XCTFail("Expected validationFailed error")
                return
            }
            XCTAssertTrue(message.contains("protected system process"))
        }
    }
    
    func testProcessKillerInvalidPID() async {
        await XCTAssertThrowsErrorAsync(try await ProcessKiller.killProcessById(-1)) { error in
            guard case CommandError.validationFailed(let message) = error else {
                XCTFail("Expected validationFailed error")
                return
            }
            XCTAssertTrue(message.contains("Invalid process ID"))
        }
    }
    
    // MARK: - ErrorHandler Tests
    
    func testErrorHandlerExitCodeMapping() {
        // Test common exit codes
        let error126 = ErrorHandler.mapExitCodeToError(126, command: MockCommand(), originalError: "Permission denied")
        XCTAssertEqual(error126, CommandError.permissionDenied)
        
        let error127 = ErrorHandler.mapExitCodeToError(127, command: MockCommand(), originalError: "Command not found")
        if case CommandError.validationFailed(let message) = error127 {
            XCTAssertTrue(message.contains("not found"))
        } else {
            XCTFail("Expected validationFailed error for exit code 127")
        }
        
        let signalError = ErrorHandler.mapExitCodeToError(130, command: MockCommand(), originalError: "Interrupted")
        if case CommandError.executionFailed(let exitCode, let stderr) = signalError {
            XCTAssertEqual(exitCode, 130)
            XCTAssertTrue(stderr.contains("signal"))
        } else {
            XCTFail("Expected executionFailed error for signal exit code")
        }
    }
    
    func testErrorHandlerRecoverySuggestions() {
        let validationError = CommandError.validationFailed("Command 'nonexistent' not found")
        let suggestions = ErrorHandler.getRecoverySuggestions(for: validationError)
        
        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertTrue(suggestions.contains { $0.contains("Install") || $0.contains("PATH") })
        
        let permissionError = CommandError.permissionDenied
        let permissionSuggestions = ErrorHandler.getRecoverySuggestions(for: permissionError)
        
        XCTAssertFalse(permissionSuggestions.isEmpty)
        XCTAssertTrue(permissionSuggestions.contains { $0.contains("sudo") || $0.contains("permission") })
    }
    
    func testErrorHandlerDetailedError() {
        let originalError = CommandError.validationFailed("Test error")
        let context = ErrorContext(command: "test", arguments: ["arg1", "arg2"])
        let detailedError = ErrorHandler.createDetailedError(originalError, context: context)
        
        XCTAssertEqual(detailedError.originalError, originalError)
        XCTAssertEqual(detailedError.context.command, "test")
        XCTAssertEqual(detailedError.context.arguments, ["arg1", "arg2"])
        XCTAssertFalse(detailedError.recoverySuggestions.isEmpty)
        
        let formatted = detailedError.formattedDescription
        XCTAssertTrue(formatted.contains("Test error"))
        XCTAssertTrue(formatted.contains("test arg1 arg2"))
        XCTAssertTrue(formatted.contains("Recovery Suggestions"))
    }
    
    // MARK: - Helper Functions for Async Testing
    
    func XCTAssertThrowsErrorAsync<T>(
        _ expression: @autoclosure () async throws -> T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line,
        _ errorHandler: (_ error: Error) -> Void = { _ in }
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected error but got success", file: file, line: line)
        } catch {
            errorHandler(error)
        }
    }
}

// MARK: - CommandError Equatable for Testing

extension CommandError: Equatable {
    public static func == (lhs: CommandError, rhs: CommandError) -> Bool {
        switch (lhs, rhs) {
        case (.validationFailed(let lhsMessage), .validationFailed(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.executionFailed(let lhsCode, let lhsStderr), .executionFailed(let rhsCode, let rhsStderr)):
            return lhsCode == rhsCode && lhsStderr == rhsStderr
        case (.sudoRequired, .sudoRequired),
             (.outputParsingFailed, .outputParsingFailed),
             (.permissionDenied, .permissionDenied),
             (.timeout, .timeout):
            return true
        case (.unknownDomain(let lhsDomain), .unknownDomain(let rhsDomain)):
            return lhsDomain == rhsDomain
        case (.unknownKey(let lhsKey), .unknownKey(let rhsKey)):
            return lhsKey == rhsKey
        case (.typeMismatch(let lhsExpected, let lhsActual), .typeMismatch(let rhsExpected, let rhsActual)):
            return lhsExpected == rhsExpected && lhsActual == rhsActual
        case (.invalidOutput(let lhsMessage), .invalidOutput(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}