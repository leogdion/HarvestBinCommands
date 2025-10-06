import Foundation
import ServiceManagement

/// Manages installation and communication with a privileged helper tool
/// The helper persists across app launches - no password needed after first install
public actor HelperToolManager {
    public static let shared = HelperToolManager()

    private let helperIdentifier = "com.harvestbin.helper"
    private var isHelperInstalled = false

    private init() {}

    /// Install the privileged helper tool (prompts for password once)
    public func installHelper() async throws {
        if isHelperInstalled {
            return
        }

        // Check if already installed
        if await checkHelperStatus() {
            isHelperInstalled = true
            return
        }

        // Install using SMJobBless
        var authRef: AuthorizationRef?
        let rightName = strdup(kSMRightBlessPrivilegedHelper)
        defer { free(rightName) }

        var authItem = AuthorizationItem(
            name: rightName!,
            valueLength: 0,
            value: nil,
            flags: 0
        )

        var authRights = AuthorizationRights(count: 1, items: &authItem)
        let flags: AuthorizationFlags = [.interactionAllowed, .extendRights, .preAuthorize]

        let status = AuthorizationCreate(&authRights, nil, flags, &authRef)

        guard status == errAuthorizationSuccess, let auth = authRef else {
            throw CommandError.permissionDenied
        }

        var error: Unmanaged<CFError>?
        let success = SMJobBless(
            kSMDomainSystemLaunchd,
            helperIdentifier as CFString,
            auth,
            &error
        )

        AuthorizationFree(auth, [])

        if success {
            self.isHelperInstalled = true
        } else {
            let err = error?.takeRetainedValue() as Error?
            throw err ?? CommandError.permissionDenied
        }
    }

    private func setHelperInstalled(_ installed: Bool) {
        self.isHelperInstalled = installed
    }

    /// Check if helper is installed and running
    public func checkHelperStatus() async -> Bool {
        // Try to connect to the helper via XPC
        // For now, simple check
        let fm = FileManager.default
        let helperPath = "/Library/PrivilegedHelperTools/\(helperIdentifier)"
        return fm.fileExists(atPath: helperPath)
    }

    /// Execute command via helper tool (no password needed)
    public func executeViaHelper(command: String, arguments: [String]) async throws -> (exitCode: Int32, output: String) {
        if !isHelperInstalled {
            throw CommandError.validationFailed("Helper tool not installed. Call installHelper() first.")
        }

        // TODO: Implement XPC communication with helper
        // For now, use a simpler approach with authorization services
        return try await AuthorizationManager.shared.executeAsRoot(
            command: command,
            arguments: arguments
        )
    }
}

// MARK: - Alternative: Persistent Authorization via Keychain

extension HelperToolManager {
    /// Store authorization credentials in keychain for reuse
    /// Note: This is less secure than a helper tool but simpler
    public func enablePersistentAuthorization() async throws {
        // Use Authorization Services with kAuthorizationFlagExtendRights
        // and store the authorization externally

        try await AuthorizationManager.shared.requestAuthorization()

        // Create persistent authorization that survives app restarts
        var authRef: AuthorizationRef?
        var status = AuthorizationCreate(nil, nil, [], &authRef)

        guard status == errAuthorizationSuccess, let auth = authRef else {
            throw CommandError.permissionDenied
        }

        // Create authorization item for admin rights
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

            // Request rights with extended duration
            let flags: AuthorizationFlags = [
                .interactionAllowed,
                .extendRights,
                .preAuthorize
            ]

            status = AuthorizationCopyRights(auth, &rights, nil, flags, nil)
        }

        if status == errAuthorizationSuccess {
            // Convert authorization to external form for storage
            var extForm = AuthorizationExternalForm()
            status = AuthorizationMakeExternalForm(auth, &extForm)

            if status == errAuthorizationSuccess {
                // Store in user defaults (or keychain for better security)
                let data = Data(bytes: &extForm.bytes, count: Int(kAuthorizationExternalFormLength))
                UserDefaults.standard.set(data, forKey: "HarvestBinAuthorization")
            }
        }

        AuthorizationFree(auth, [])
    }

    /// Load authorization from keychain (if available)
    public func loadPersistentAuthorization() async -> Bool {
        guard let data = UserDefaults.standard.data(forKey: "HarvestBinAuthorization") else {
            return false
        }

        var extForm = AuthorizationExternalForm()
        _ = data.withUnsafeBytes { ptr in
            memcpy(&extForm.bytes, ptr.baseAddress!, Int(kAuthorizationExternalFormLength))
        }

        var authRef: AuthorizationRef?
        let status = AuthorizationCreateFromExternalForm(&extForm, &authRef)

        guard status == errAuthorizationSuccess else {
            return false
        }

        // Verify the authorization is still valid
        let rightName = strdup(kAuthorizationRightExecute)
        defer { free(rightName) }

        var authItem = AuthorizationItem(
            name: rightName!,
            valueLength: 0,
            value: nil,
            flags: 0
        )

        var isValid = false
        withUnsafeMutablePointer(to: &authItem) { itemPtr in
            var rights = AuthorizationRights(count: 1, items: itemPtr)
            let verifyStatus = AuthorizationCopyRights(authRef!, &rights, nil, [], nil)
            isValid = (verifyStatus == errAuthorizationSuccess)
        }

        if let ref = authRef {
            AuthorizationFree(ref, [])
        }

        return isValid
    }
}
