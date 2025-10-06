import Foundation

actor FileLogger {
    static let shared = FileLogger()

    private let logFileURL: URL
    private let dateFormatter: DateFormatter

    private init() {
        // Log to current directory
        let currentDirectory = FileManager.default.currentDirectoryPath
        self.logFileURL = URL(fileURLWithPath: currentDirectory).appendingPathComponent("harvest-bin-demo.log")

        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        // Log startup
        Task {
            await log("=== HarvestBin Demo Started ===")
            await log("Log file: \(logFileURL.path)")
        }
    }

    func log(_ message: String, level: LogLevel = .info) {
        let timestamp = dateFormatter.string(from: Date())
        let logLine = "[\(timestamp)] [\(level.rawValue)] \(message)\n"

        // Write to file
        if let data = logLine.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    try? fileHandle.close()
                }
            } else {
                try? data.write(to: logFileURL, options: .atomic)
            }
        }

        // Also print to console
        print(logLine, terminator: "")
    }

    func logCommand(_ command: String, arguments: [String], requiresSudo: Bool) {
        let cmd = requiresSudo ? "sudo \(command)" : command
        let fullCommand = "\(cmd) \(arguments.joined(separator: " "))"
        log("Executing: \(fullCommand)", level: .command)
    }

    func logResult(exitCode: Int32, executionTime: TimeInterval, output: String, error: String) {
        log("Exit code: \(exitCode), Time: \(String(format: "%.3f", executionTime))s", level: .result)
        if !output.isEmpty {
            log("Output: \(output.prefix(200))", level: .result)
        }
        if !error.isEmpty {
            log("Error: \(error)", level: .error)
        }
    }

    func logError(_ error: Error) {
        log("Error: \(error.localizedDescription)", level: .error)
    }

    func getLogPath() -> String {
        logFileURL.path
    }

    func getLogContents() -> String {
        guard let contents = try? String(contentsOf: logFileURL, encoding: .utf8) else {
            return "No log file found"
        }
        return contents
    }

    func clearLog() {
        try? FileManager.default.removeItem(at: logFileURL)
        log("=== Log Cleared ===")
    }

    enum LogLevel: String {
        case info = "INFO"
        case command = "CMD"
        case result = "RESULT"
        case error = "ERROR"
        case debug = "DEBUG"
    }
}
