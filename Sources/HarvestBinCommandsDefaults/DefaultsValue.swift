import Foundation
import HarvestBinCommandsCore

public protocol DefaultsValue {
    static var defaultsType: String { get }
    func toDefaultsArgument() -> String
    static func from(defaultsOutput: String) throws -> Self
}

// MARK: - Bool Conformance
extension Bool: DefaultsValue {
    public static var defaultsType: String { "bool" }
    
    public func toDefaultsArgument() -> String {
        return self ? "true" : "false"
    }
    
    public static func from(defaultsOutput: String) throws -> Bool {
        let trimmed = defaultsOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        switch trimmed.lowercased() {
        case "1", "true", "yes":
            return true
        case "0", "false", "no":
            return false
        default:
            throw CommandError.typeMismatch(expected: "bool", actual: defaultsOutput)
        }
    }
}

// MARK: - String Conformance
extension String: DefaultsValue {
    public static var defaultsType: String { "string" }
    
    public func toDefaultsArgument() -> String {
        return self
    }
    
    public static func from(defaultsOutput: String) throws -> String {
        let trimmed = defaultsOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        // Remove quotes if present
        if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) ||
           (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
            return String(trimmed.dropFirst().dropLast())
        }
        return trimmed
    }
}

// MARK: - Int Conformance
extension Int: DefaultsValue {
    public static var defaultsType: String { "int" }
    
    public func toDefaultsArgument() -> String {
        return String(self)
    }
    
    public static func from(defaultsOutput: String) throws -> Int {
        let trimmed = defaultsOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed) else {
            throw CommandError.typeMismatch(expected: "int", actual: defaultsOutput)
        }
        return value
    }
}

// MARK: - Float Conformance
extension Float: DefaultsValue {
    public static var defaultsType: String { "float" }
    
    public func toDefaultsArgument() -> String {
        return String(self)
    }
    
    public static func from(defaultsOutput: String) throws -> Float {
        let trimmed = defaultsOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Float(trimmed) else {
            throw CommandError.typeMismatch(expected: "float", actual: defaultsOutput)
        }
        return value
    }
}