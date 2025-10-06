import Foundation
import HarvestBinCommandsCore

/// Command to enable or disable remote access services on macOS
public struct RemoteAccessCommand: CommandProtocol {
    public let service: Service
    public let enabled: Bool

    public enum Service: String, Sendable {
        case ssh = "com.openssh.sshd"
        case screenSharing = "com.apple.screensharing"
        case remoteManagement = "com.apple.RemoteManagement"

        var displayName: String {
            switch self {
            case .ssh: return "SSH (Remote Login)"
            case .screenSharing: return "Screen Sharing"
            case .remoteManagement: return "Remote Management"
            }
        }

        var launchDaemonPath: String {
            switch self {
            case .ssh:
                return "/System/Library/LaunchDaemons/ssh.plist"
            case .screenSharing:
                return "/System/Library/LaunchDaemons/com.apple.screensharing.plist"
            case .remoteManagement:
                return "/System/Library/LaunchDaemons/com.apple.RemoteManagement.plist"
            }
        }
    }

    public var command: String {
        "/bin/launchctl"
    }

    public var arguments: [String] {
        if enabled {
            return ["load", "-w", service.launchDaemonPath]
        } else {
            return ["unload", "-w", service.launchDaemonPath]
        }
    }

    public var requiresSudo: Bool {
        true
    }

    public var affectedProcess: String? {
        nil
    }

    public init(service: Service, enabled: Bool) {
        self.service = service
        self.enabled = enabled
    }

    public func validate() throws {
        // Check if the launch daemon file exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: service.launchDaemonPath) else {
            throw CommandError.validationFailed("Launch daemon not found at \(service.launchDaemonPath)")
        }

        // Validate that we're on macOS
        #if !os(macOS)
        throw CommandError.validationFailed("Remote access commands are only supported on macOS")
        #endif
    }
}

// MARK: - Service Status Check

extension RemoteAccessCommand {
    /// Check if a service is currently enabled
    public static func isServiceEnabled(_ service: Service) async throws -> Bool {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["print-disabled", "system"]
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw CommandError.outputParsingFailed
        }

        // If the service appears in print-disabled with "true", it's disabled
        // If it appears with "false" or doesn't appear, it's enabled
        let lines = output.split(separator: "\n")
        for line in lines {
            if line.contains(service.rawValue) {
                return !line.contains("=> true")
            }
        }

        // If not found in disabled list, assume enabled
        return true
    }
}
