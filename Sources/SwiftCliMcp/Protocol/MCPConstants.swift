import Foundation

// MARK: - MCP Protocol Constants

enum MCPConstants {
    static let protocolVersion = "2024-11-05"

    // JSON-RPC error codes
    static let parseError = -32700
    static let methodNotFound = -32601
    static let invalidParams = -32602
    static let internalError = -32603
}
