import Foundation
import Security

/// Manages macOS Authorization Services for privileged operations
public actor AuthorizationManager {
    public static let shared = AuthorizationManager()

    private var authorizationRef: AuthorizationRef?
    private var isAuthorized: Bool = false

    private init() {}

    /// Request authorization once - credentials are cached for the app lifetime
    public func requestAuthorization() async throws {
        if isAuthorized, authorizationRef != nil {
            // Already authorized
            return
        }

        var authRef: AuthorizationRef?

        // Create authorization
        var status = AuthorizationCreate(nil, nil, [], &authRef)
        guard status == errAuthorizationSuccess else {
            throw CommandError.permissionDenied
        }

        // Define the rights we need
        let rightName = strdup(kAuthorizationRightExecute)
        defer { free(rightName) }

        var authItem = AuthorizationItem(
            name: rightName!,
            valueLength: 0,
            value: nil,
            flags: 0
        )

        withUnsafeMutablePointer(to: &authItem) { itemPtr in
            var rights = AuthorizationRights(count: 1, items: itemPtr)

            // Request the rights with user interaction
            let flags: AuthorizationFlags = [
                .interactionAllowed,
                .extendRights,
                .preAuthorize
            ]

            status = AuthorizationCopyRights(
                authRef!,
                &rights,
                nil,
                flags,
                nil
            )
        }

        if status == errAuthorizationSuccess {
            self.authorizationRef = authRef
            self.isAuthorized = true
        } else {
            // Clean up on failure
            if let ref = authRef {
                AuthorizationFree(ref, [])
            }
            throw CommandError.permissionDenied
        }
    }

    private func setAuthorization(_ ref: AuthorizationRef?) {
        self.authorizationRef = ref
        self.isAuthorized = ref != nil
    }

    /// Execute a command with elevated privileges using cached authorization
    public func executeAsRoot(command: String, arguments: [String]) async throws -> (exitCode: Int32, output: String) {
        guard authorizationRef != nil else {
            throw CommandError.permissionDenied
        }

        // Use a helper approach - write script and execute with sudo
        let tempDir = FileManager.default.temporaryDirectory
        let scriptPath = tempDir.appendingPathComponent("harvestbin-\(UUID().uuidString).sh")

        let script = """
        #!/bin/sh
        \(command) \(arguments.map { "'\($0)'" }.joined(separator: " "))
        """

        try script.write(to: scriptPath, atomically: true, encoding: .utf8)

        // Make executable
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)

        // Execute via Process (authorization already obtained, stored in system)
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
            process.arguments = ["-n", scriptPath.path] // -n means no password (use cached)
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            process.terminationHandler = { proc in
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                let stdout = String(data: outputData, encoding: .utf8) ?? ""
                let stderr = String(data: errorData, encoding: .utf8) ?? ""

                // Clean up
                try? FileManager.default.removeItem(at: scriptPath)

                let output = stdout.isEmpty ? stderr : stdout
                continuation.resume(returning: (exitCode: proc.terminationStatus, output: output))
            }

            do {
                try process.run()
            } catch {
                try? FileManager.default.removeItem(at: scriptPath)
                continuation.resume(throwing: CommandError.executionFailed(exitCode: -1, stderr: error.localizedDescription))
            }
        }
    }

    /// Check if we have valid authorization
    public func hasAuthorization() -> Bool {
        return isAuthorized && authorizationRef != nil
    }

    /// Release authorization (usually not needed - done automatically on app exit)
    public func releaseAuthorization() {
        if let ref = authorizationRef {
            AuthorizationFree(ref, [])
            authorizationRef = nil
            isAuthorized = false
        }
    }

    // Note: deinit cannot access actor-isolated properties in Swift 6
    // The authorization will be cleaned up when the process exits
}
