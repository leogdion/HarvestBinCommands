//
//  SwiftUIView.swift
//  HarvestBinCommands
//
//  Created by Leo on 10/6/25.
//

import SwiftUI
import HarvestBinCommandsCore
import HarvestBinCommandsDefaults
import HarvestBinCommandsAdmin
import Security

struct ContentView: View {
    @State private var outputText: String = "Ready to test commands..."
    @State private var isLoading: Bool = false
    @State private var showingLogViewer: Bool = false
    @State private var logPath: String = ""

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("HarvestBin Command Tester")
                    .font(.largeTitle)

                Spacer()

                Button(action: {
                    Task {
                        logPath = await FileLogger.shared.getLogPath()
                        showingLogViewer = true
                    }
                }) {
                    Image(systemName: "doc.text.fill")
                    Text("View Logs")
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)

            ScrollView {
                Text(outputText)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            .frame(minHeight: 200)
            .padding(.horizontal)

            VStack(spacing: 12) {
                Text("Type Tests")
                    .font(.headline)

                HStack(spacing: 12) {
                    Button("Test Bool") {
                        Task { await testBoolType() }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Test String") {
                        Task { await testStringType() }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Test Int") {
                        Task { await testIntType() }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Test Float") {
                        Task { await testFloatType() }
                    }
                    .buttonStyle(.borderedProminent)
                }

                Text("Real Defaults Commands")
                    .font(.headline)
                    .padding(.top)

                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Button("Read Defaults") {
                            Task { await testReadDefaults() }
                        }
                        .buttonStyle(.borderedProminent)

                        Button("List Domains") {
                            Task { await testListDomains() }
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    HStack(spacing: 12) {
                        Button("Write & Read Test") {
                            Task { await testWriteAndRead() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                }

                Text("Remote Access Commands (requires sudo)")
                    .font(.headline)
                    .padding(.top)

                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Button("Check SSH Status") {
                            Task { await checkSSHStatus() }
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Enable SSH") {
                            Task { await enableSSH() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)

                        Button("Disable SSH") {
                            Task { await disableSSH() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }

                Button("Clear Output") {
                    outputText = "Ready to test commands..."
                }
                .buttonStyle(.bordered)
                .padding(.top)
            }
            .disabled(isLoading)
            .padding()
        }
        .frame(minWidth: 700, minHeight: 500)
        .padding()
        .sheet(isPresented: $showingLogViewer) {
            LogViewerView(logPath: logPath)
        }
        .task {
            logPath = await FileLogger.shared.getLogPath()
            await FileLogger.shared.log("ContentView appeared")

            // Try to load persistent authorization
            let hasAuth = await HelperToolManager.shared.loadPersistentAuthorization()
            if hasAuth {
                await FileLogger.shared.log("Loaded persistent authorization from previous session")
            }
        }
    }

    // MARK: - Type Tests

    func testBoolType() async {
        isLoading = true
        outputText = "Testing Bool type conversions...\n"
        await FileLogger.shared.log("Starting Bool type test")

        do {
            // Test true values
            let true1 = try Bool.from(defaultsOutput: "1")
            let true2 = try Bool.from(defaultsOutput: "true")
            let true3 = try Bool.from(defaultsOutput: "YES")

            // Test false values
            let false1 = try Bool.from(defaultsOutput: "0")
            let false2 = try Bool.from(defaultsOutput: "false")
            let false3 = try Bool.from(defaultsOutput: "NO")

            outputText += "✅ Bool parsing successful:\n"
            outputText += "  '1' → \(true1)\n"
            outputText += "  'true' → \(true2)\n"
            outputText += "  'YES' → \(true3)\n"
            outputText += "  '0' → \(false1)\n"
            outputText += "  'false' → \(false2)\n"
            outputText += "  'NO' → \(false3)\n\n"

            // Test to argument
            outputText += "toDefaultsArgument():\n"
            outputText += "  true → '\(true.toDefaultsArgument())'\n"
            outputText += "  false → '\(false.toDefaultsArgument())'\n"

        } catch {
            outputText += "❌ Error: \(error.localizedDescription)\n"
        }

        isLoading = false
    }

    func testStringType() async {
        isLoading = true
        outputText = "Testing String type conversions...\n"

        do {
            let str1 = try String.from(defaultsOutput: "hello")
            let str2 = try String.from(defaultsOutput: "\"quoted string\"")
            let str3 = try String.from(defaultsOutput: "'single quoted'")
            let str4 = try String.from(defaultsOutput: "  spaces  ")

            outputText += "✅ String parsing successful:\n"
            outputText += "  'hello' → '\(str1)'\n"
            outputText += "  '\"quoted string\"' → '\(str2)'\n"
            outputText += "  \"'single quoted'\" → '\(str3)'\n"
            outputText += "  '  spaces  ' → '\(str4)'\n\n"

            outputText += "toDefaultsArgument():\n"
            outputText += "  'test' → '\("test".toDefaultsArgument())'\n"

        } catch {
            outputText += "❌ Error: \(error.localizedDescription)\n"
        }

        isLoading = false
    }

    func testIntType() async {
        isLoading = true
        outputText = "Testing Int type conversions...\n"

        do {
            let int1 = try Int.from(defaultsOutput: "42")
            let int2 = try Int.from(defaultsOutput: "-100")
            let int3 = try Int.from(defaultsOutput: "  999  ")

            outputText += "✅ Int parsing successful:\n"
            outputText += "  '42' → \(int1)\n"
            outputText += "  '-100' → \(int2)\n"
            outputText += "  '  999  ' → \(int3)\n\n"

            outputText += "toDefaultsArgument():\n"
            outputText += "  123 → '\(123.toDefaultsArgument())'\n"

        } catch {
            outputText += "❌ Error: \(error.localizedDescription)\n"
        }

        isLoading = false
    }

    func testFloatType() async {
        isLoading = true
        outputText = "Testing Float type conversions...\n"

        do {
            let float1 = try Float.from(defaultsOutput: "3.14")
            let float2 = try Float.from(defaultsOutput: "-2.5")
            let float3 = try Float.from(defaultsOutput: "  42.0  ")

            outputText += "✅ Float parsing successful:\n"
            outputText += "  '3.14' → \(float1)\n"
            outputText += "  '-2.5' → \(float2)\n"
            outputText += "  '  42.0  ' → \(float3)\n\n"

            outputText += "toDefaultsArgument():\n"
            outputText += "  1.5 → '\(Float(1.5).toDefaultsArgument())'\n"

        } catch {
            outputText += "❌ Error: \(error.localizedDescription)\n"
        }

        isLoading = false
    }

    // MARK: - Real Defaults Commands

    func testReadDefaults() async {
        isLoading = true
        outputText = "Testing 'defaults read' command...\n\n"

        // Test with NSGlobalDomain which should have values
        let command = DefaultsReadCommand(domain: "NSGlobalDomain", key: "AppleLanguages")
        await FileLogger.shared.logCommand(command.command, arguments: command.arguments, requiresSudo: command.requiresSudo)

        do {
            let result = try await CommandExecutor.shared.execute(command)
            await FileLogger.shared.logResult(exitCode: result.exitCode, executionTime: result.executionTime, output: result.standardOutput, error: result.standardError)
            outputText += "✅ Command executed successfully:\n"
            outputText += "Domain: NSGlobalDomain\n"
            outputText += "Key: AppleLanguages\n"
            outputText += "Exit Code: \(result.exitCode)\n"
            outputText += "Output:\n\(result.standardOutput)\n"
            outputText += "Execution Time: \(String(format: "%.3f", result.executionTime))s\n"

            if !result.standardError.isEmpty {
                outputText += "\nStderr: \(result.standardError)\n"
            }

            // Now test a key that doesn't exist
            outputText += "\n--- Testing non-existent key ---\n"
            let command2 = DefaultsReadCommand(domain: "com.apple.finder", key: "AppleShowAllFiles")
            do {
                let result2 = try await CommandExecutor.shared.execute(command2)
                outputText += "✅ Key exists with value: \(result2.standardOutput)\n"
            } catch {
                outputText += "⚠️ Key doesn't exist (expected): \(error.localizedDescription)\n"
            }

        } catch {
            outputText += "❌ Error: \(error.localizedDescription)\n"
        }

        isLoading = false
    }

    func testListDomains() async {
        isLoading = true
        outputText = "Testing 'defaults domains' command...\n\n"

        let command = DefaultsDomainsCommand()
        await FileLogger.shared.logCommand(command.command, arguments: command.arguments, requiresSudo: command.requiresSudo)

        do {
            let result = try await CommandExecutor.shared.execute(command)
            await FileLogger.shared.logResult(exitCode: result.exitCode, executionTime: result.executionTime, output: result.standardOutput, error: result.standardError)
            outputText += "✅ Command executed successfully:\n"
            outputText += "Exit Code: \(result.exitCode)\n"
            outputText += "Execution Time: \(String(format: "%.3f", result.executionTime))s\n\n"

            let domains = result.standardOutput.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            outputText += "Found \(domains.count) domains:\n"
            outputText += domains.prefix(20).joined(separator: "\n")

            if domains.count > 20 {
                outputText += "\n... and \(domains.count - 20) more"
            }

        } catch {
            outputText += "❌ Error: \(error.localizedDescription)\n"
        }

        isLoading = false
    }

    func testWriteAndRead() async {
        isLoading = true
        outputText = "Testing write and read cycle...\n\n"
        await FileLogger.shared.log("Starting write and read test")

        let testDomain = "com.harvestbin.test"
        let testKey = "TestKey"
        let testValue = "HelloWorld123"

        do {
            // Write a test value
            outputText += "Step 1: Writing test value...\n"
            let writeCmd = DefaultsWriteCommand(domain: testDomain, key: testKey, value: testValue)
            await FileLogger.shared.logCommand(writeCmd.command, arguments: writeCmd.arguments, requiresSudo: writeCmd.requiresSudo)
            let writeResult = try await CommandExecutor.shared.execute(writeCmd)
            await FileLogger.shared.logResult(exitCode: writeResult.exitCode, executionTime: writeResult.executionTime, output: writeResult.standardOutput, error: writeResult.standardError)
            outputText += "✅ Write successful (exit code: \(writeResult.exitCode))\n"
            outputText += "  Domain: \(testDomain)\n"
            outputText += "  Key: \(testKey)\n"
            outputText += "  Value: \(testValue)\n\n"

            // Read it back
            outputText += "Step 2: Reading value back...\n"
            let readCmd = DefaultsReadCommand(domain: testDomain, key: testKey)
            let readResult = try await CommandExecutor.shared.execute(readCmd)
            let readValue = readResult.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            outputText += "✅ Read successful (exit code: \(readResult.exitCode))\n"
            outputText += "  Retrieved value: \(readValue)\n\n"

            // Verify
            if readValue == testValue {
                outputText += "✅ VERIFICATION PASSED: Values match!\n"
            } else {
                outputText += "❌ VERIFICATION FAILED: Values don't match\n"
                outputText += "  Expected: \(testValue)\n"
                outputText += "  Got: \(readValue)\n"
            }

            // Clean up
            outputText += "\nStep 3: Cleaning up...\n"
            let deleteCmd = DefaultsDeleteCommand(domain: testDomain, key: testKey)
            let deleteResult = try await CommandExecutor.shared.execute(deleteCmd)
            outputText += "✅ Test key deleted (exit code: \(deleteResult.exitCode))\n"

        } catch {
            outputText += "❌ Error: \(error.localizedDescription)\n"
        }

        isLoading = false
    }

    // MARK: - Remote Access Commands

    func checkSSHStatus() async {
        isLoading = true
        outputText = "Checking SSH service status...\n\n"
        await FileLogger.shared.log("Checking SSH status")

        do {
            let isEnabled = try await RemoteAccessCommand.isServiceEnabled(.ssh)
            await FileLogger.shared.log("SSH status: \(isEnabled ? "enabled" : "disabled")")
            outputText += "SSH Service Status:\n"
            outputText += isEnabled ? "✅ ENABLED\n" : "❌ DISABLED\n"
            outputText += "\nService: SSH (Remote Login)\n"
            outputText += "Launch Daemon: com.openssh.sshd\n"
        } catch {
            outputText += "❌ Error checking status: \(error.localizedDescription)\n"
        }

        isLoading = false
    }

    func enableSSH() async {
        isLoading = true
        outputText = "Enabling SSH service...\n\n"

        let command = RemoteAccessCommand(service: .ssh, enabled: true)
        await FileLogger.shared.logCommand(command.command, arguments: command.arguments, requiresSudo: command.requiresSudo)

        do {
            outputText += "⚠️ This operation requires administrator privileges.\n"

            // First time will prompt, then caches for future app launches
            try await HelperToolManager.shared.enablePersistentAuthorization()
            outputText += "✅ Authorization cached for future sessions\n\n"

            let result = try await CommandExecutor.shared.execute(command)
            await FileLogger.shared.logResult(exitCode: result.exitCode, executionTime: result.executionTime, output: result.standardOutput, error: result.standardError)
            outputText += "✅ SSH enabled successfully!\n"
            outputText += "Exit Code: \(result.exitCode)\n"
            outputText += "Execution Time: \(String(format: "%.3f", result.executionTime))s\n\n"

            outputText += "SSH is now running on port 22.\n"
            outputText += "You can connect with: ssh \(NSUserName())@localhost\n"

        } catch {
            await FileLogger.shared.logError(error)
            outputText += "❌ Error: \(error.localizedDescription)\n\n"
            outputText += "Note: This requires administrator privileges.\n"
            outputText += "Make sure you have sudo access.\n"
        }

        isLoading = false
    }

    func disableSSH() async {
        isLoading = true
        outputText = "Disabling SSH service...\n\n"

        let command = RemoteAccessCommand(service: .ssh, enabled: false)
        await FileLogger.shared.logCommand(command.command, arguments: command.arguments, requiresSudo: command.requiresSudo)

        do {
            outputText += "⚠️ This operation requires sudo privileges.\n"
            outputText += "You may be prompted for your password.\n\n"

            let result = try await CommandExecutor.shared.execute(command)
            await FileLogger.shared.logResult(exitCode: result.exitCode, executionTime: result.executionTime, output: result.standardOutput, error: result.standardError)
            outputText += "✅ SSH disabled successfully!\n"
            outputText += "Exit Code: \(result.exitCode)\n"
            outputText += "Execution Time: \(String(format: "%.3f", result.executionTime))s\n\n"

            outputText += "SSH is no longer accepting connections.\n"

        } catch {
            await FileLogger.shared.logError(error)
            outputText += "❌ Error: \(error.localizedDescription)\n\n"
            outputText += "Note: This requires administrator privileges.\n"
            outputText += "Make sure you have sudo access.\n"
        }

        isLoading = false
    }
}

// MARK: - Log Viewer

struct LogViewerView: View {
    let logPath: String
    @State private var logContents: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Command Log")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button("Refresh") {
                    Task { await refreshLog() }
                }
                .buttonStyle(.bordered)

                Button("Clear Log") {
                    Task {
                        await FileLogger.shared.clearLog()
                        await refreshLog()
                    }
                }
                .buttonStyle(.bordered)

                Button("Copy Path") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(logPath, forType: .string)
                }
                .buttonStyle(.bordered)

                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Text("Log file: \(logPath)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            Divider()

            ScrollView {
                Text(logContents)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .textSelection(.enabled)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .task {
            await refreshLog()
        }
    }

    func refreshLog() async {
        logContents = await FileLogger.shared.getLogContents()
    }
}

// MARK: - Test Commands

struct DefaultsReadCommand: CommandProtocol {
    let domain: String
    let key: String

    var command: String { "/usr/bin/defaults" }
    var arguments: [String] { ["read", domain, key] }
    var requiresSudo: Bool { false }
    var affectedProcess: String? { nil }

    func validate() throws {
        // Basic validation
    }
}

struct DefaultsDomainsCommand: CommandProtocol {
    var command: String { "/usr/bin/defaults" }
    var arguments: [String] { ["domains"] }
    var requiresSudo: Bool { false }
    var affectedProcess: String? { nil }

    func validate() throws {
        // Basic validation
    }
}

struct DefaultsWriteCommand: CommandProtocol {
    let domain: String
    let key: String
    let value: String

    var command: String { "/usr/bin/defaults" }
    var arguments: [String] { ["write", domain, key, "-string", value] }
    var requiresSudo: Bool { false }
    var affectedProcess: String? { nil }

    func validate() throws {
        // Basic validation
    }
}

struct DefaultsDeleteCommand: CommandProtocol {
    let domain: String
    let key: String

    var command: String { "/usr/bin/defaults" }
    var arguments: [String] { ["delete", domain, key] }
    var requiresSudo: Bool { false }
    var affectedProcess: String? { nil }

    func validate() throws {
        // Basic validation
    }
}

#Preview {
    ContentView()
}
