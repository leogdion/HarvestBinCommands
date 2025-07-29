import Foundation

public protocol CommandProtocol: Sendable {
    var command: String { get }
    var arguments: [String] { get }
    var requiresSudo: Bool { get }
    var affectedProcess: String? { get }
    
    func validate() throws
}