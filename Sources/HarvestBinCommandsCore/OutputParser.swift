import Foundation

public struct OutputParser {
    
    public static func parseJSON<T: Decodable>(_ output: String, as type: T.Type) throws -> T {
        let cleanedOutput = cleanOutput(output)
        guard let data = cleanedOutput.data(using: .utf8) else {
            throw CommandError.outputParsingFailed
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(type, from: data)
        } catch {
            throw CommandError.outputParsingFailed
        }
    }
    
    public static func parsePlist<T: Decodable>(_ output: String, as type: T.Type) throws -> T {
        let cleanedOutput = cleanOutput(output)
        guard let data = cleanedOutput.data(using: .utf8) else {
            throw CommandError.outputParsingFailed
        }
        
        do {
            let decoder = PropertyListDecoder()
            return try decoder.decode(type, from: data)
        } catch {
            throw CommandError.outputParsingFailed
        }
    }
    
    public static func parseKeyValuePairs(_ output: String, separator: String = "=") -> [String: String] {
        let cleanedOutput = cleanOutput(output)
        var result: [String: String] = [:]
        
        let lines = cleanedOutput.components(separatedBy: .newlines)
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }
            
            let components = trimmedLine.components(separatedBy: separator)
            if components.count >= 2 {
                let key = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let value = components[1...].joined(separator: separator).trimmingCharacters(in: .whitespacesAndNewlines)
                result[key] = value
            }
        }
        
        return result
    }
    
    public static func parseLines(_ output: String, skipEmpty: Bool = true) -> [String] {
        let cleanedOutput = cleanOutput(output)
        let lines = cleanedOutput.components(separatedBy: .newlines)
        
        if skipEmpty {
            return lines.compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
        } else {
            return lines
        }
    }
    
    public static func parseColumnarOutput(_ output: String, headerLine: Int = 0) -> [[String]] {
        let lines = parseLines(output, skipEmpty: true)
        guard lines.count > headerLine else { return [] }
        
        var result: [[String]] = []
        for (index, line) in lines.enumerated() {
            if index == headerLine {
                continue // Skip header line
            }
            
            let columns = line.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
            result.append(columns)
        }
        
        return result
    }
    
    public static func cleanOutput(_ output: String) -> String {
        // Remove ANSI color codes and other control sequences
        let ansiPattern = "\\x1B\\[[0-?]*[ -/]*[@-~]"
        let regex = try? NSRegularExpression(pattern: ansiPattern, options: [])
        let range = NSRange(location: 0, length: output.utf16.count)
        let cleanedOutput = regex?.stringByReplacingMatches(in: output, options: [], range: range, withTemplate: "") ?? output
        
        // Trim whitespace and normalize line endings
        return cleanedOutput
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }
    
    public static func detectEncoding(_ data: Data) -> String.Encoding {
        // Try UTF-8 first
        if String(data: data, encoding: .utf8) != nil {
            return .utf8
        }
        
        // Fall back to other common encodings
        let encodings: [String.Encoding] = [.ascii, .isoLatin1, .utf16, .macOSRoman]
        for encoding in encodings {
            if String(data: data, encoding: encoding) != nil {
                return encoding
            }
        }
        
        // Default to UTF-8 if nothing else works
        return .utf8
    }
    
    public static func extractValue(from output: String, key: String, format: ValueFormat = .keyValue()) -> String? {
        switch format {
        case .keyValue(let separator):
            let pairs = parseKeyValuePairs(output, separator: separator)
            return pairs[key]
        case .json(let path):
            return extractJSONValue(from: output, path: path)
        case .regex(let pattern):
            return extractRegexValue(from: output, pattern: pattern)
        }
    }
    
    private static func extractJSONValue(from output: String, path: String) -> String? {
        guard let data = cleanOutput(output).data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return nil
        }
        
        let pathComponents = path.components(separatedBy: ".")
        var current: Any = json
        
        for component in pathComponents {
            if let dict = current as? [String: Any] {
                current = dict[component] ?? ""
            } else {
                return nil
            }
        }
        
        return String(describing: current)
    }
    
    private static func extractRegexValue(from output: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }
        
        let range = NSRange(location: 0, length: output.utf16.count)
        let matches = regex.matches(in: output, options: [], range: range)
        
        guard let match = matches.first else { return nil }
        
        // Return the first capture group if available, otherwise the full match
        let captureGroupRange = match.numberOfRanges > 1 ? match.range(at: 1) : match.range
        return String(output[Range(captureGroupRange, in: output)!])
    }
}

public enum ValueFormat {
    case keyValue(separator: String = "=")
    case json(path: String)
    case regex(pattern: String)
}