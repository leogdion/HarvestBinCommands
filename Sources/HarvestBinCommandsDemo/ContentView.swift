//
//  SwiftUIView.swift
//  HarvestBinCommands
//
//  Created by Leo on 10/6/25.
//

import SwiftUI
import HarvestBinCommandsCore
import HarvestBinCommandsDefaults

struct ContentView: View {
    @State private var outputText: String = "Ready to test commands..."
    @State private var isLoading: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Defaults Command Tester")
                .font(.largeTitle)
                .padding()

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
    }

    // MARK: - Type Tests

    func testBoolType() async {
        isLoading = true
        outputText = "Testing Bool type conversions...\n"

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

        do {
            let result = try await CommandExecutor.shared.execute(command)
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

        do {
            let result = try await CommandExecutor.shared.execute(command)
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

        let testDomain = "com.harvestbin.test"
        let testKey = "TestKey"
        let testValue = "HelloWorld123"

        do {
            // Write a test value
            outputText += "Step 1: Writing test value...\n"
            let writeCmd = DefaultsWriteCommand(domain: testDomain, key: testKey, value: testValue)
            let writeResult = try await CommandExecutor.shared.execute(writeCmd)
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
