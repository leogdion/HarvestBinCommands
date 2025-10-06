import XCTest
@testable import HarvestBinCommandsAdmin
import HarvestBinCommandsCore

final class RemoteAccessCommandTests: XCTestCase {

    func testSSHCommandStructure() {
        let command = RemoteAccessCommand(service: .ssh, enabled: true)

        XCTAssertEqual(command.command, "/bin/launchctl")
        XCTAssertEqual(command.arguments, ["load", "-w", "/System/Library/LaunchDaemons/ssh.plist"])
        XCTAssertTrue(command.requiresSudo)
        XCTAssertNil(command.affectedProcess)
    }

    func testSSHDisableCommandStructure() {
        let command = RemoteAccessCommand(service: .ssh, enabled: false)

        XCTAssertEqual(command.command, "/bin/launchctl")
        XCTAssertEqual(command.arguments, ["unload", "-w", "/System/Library/LaunchDaemons/ssh.plist"])
        XCTAssertTrue(command.requiresSudo)
    }

    func testScreenSharingCommandStructure() {
        let command = RemoteAccessCommand(service: .screenSharing, enabled: true)

        XCTAssertEqual(command.command, "/bin/launchctl")
        XCTAssertEqual(command.arguments, ["load", "-w", "/System/Library/LaunchDaemons/com.apple.screensharing.plist"])
        XCTAssertTrue(command.requiresSudo)
    }

    func testServiceDisplayNames() {
        XCTAssertEqual(RemoteAccessCommand.Service.ssh.displayName, "SSH (Remote Login)")
        XCTAssertEqual(RemoteAccessCommand.Service.screenSharing.displayName, "Screen Sharing")
        XCTAssertEqual(RemoteAccessCommand.Service.remoteManagement.displayName, "Remote Management")
    }

    func testServiceRawValues() {
        XCTAssertEqual(RemoteAccessCommand.Service.ssh.rawValue, "com.openssh.sshd")
        XCTAssertEqual(RemoteAccessCommand.Service.screenSharing.rawValue, "com.apple.screensharing")
        XCTAssertEqual(RemoteAccessCommand.Service.remoteManagement.rawValue, "com.apple.RemoteManagement")
    }

    func testLaunchDaemonPaths() {
        XCTAssertEqual(RemoteAccessCommand.Service.ssh.launchDaemonPath, "/System/Library/LaunchDaemons/ssh.plist")
        XCTAssertEqual(RemoteAccessCommand.Service.screenSharing.launchDaemonPath, "/System/Library/LaunchDaemons/com.apple.screensharing.plist")
    }

    func testValidationChecksFileExists() async {
        // This test will pass on macOS where the files exist
        // On other platforms or if files are missing, it should throw
        let command = RemoteAccessCommand(service: .ssh, enabled: true)

        #if os(macOS)
        // On macOS, validation should pass if the file exists
        do {
            try command.validate()
            // If we get here, the file exists (expected on most macOS systems)
        } catch CommandError.validationFailed(let message) {
            XCTAssertTrue(message.contains("Launch daemon not found"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        #else
        // On non-macOS, validation should always fail
        XCTAssertThrowsError(try command.validate()) { error in
            guard case CommandError.validationFailed(let message) = error else {
                XCTFail("Expected validationFailed error")
                return
            }
            XCTAssertTrue(message.contains("only supported on macOS"))
        }
        #endif
    }
}
