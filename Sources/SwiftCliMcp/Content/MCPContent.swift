import Foundation

// MARK: - Content Types

/// Represents different content types that MCP tools can return.
public enum MCPContent: Sendable {
    case text(String)
    case image(data: Data, mimeType: String)
    case resource(uri: String, mimeType: String?, text: String?)

    func toDict() -> [String: Any] {
        switch self {
        case .text(let str):
            return ["type": "text", "text": str]
        case .image(let data, let mimeType):
            return ["type": "image", "data": data.base64EncodedString(), "mimeType": mimeType]
        case .resource(let uri, let mimeType, let text):
            var dict: [String: Any] = ["type": "resource", "uri": uri]
            if let mimeType { dict["mimeType"] = mimeType }
            if let text { dict["text"] = text }
            return dict
        }
    }
}

// MARK: - Tool Result

/// Result returned by tool handlers.
public enum MCPToolResult: Sendable {
    case text(String) // Convenience for single text response
    case content([MCPContent]) // Advanced: multiple content blocks

    var contentArray: [[String: Any]] {
        switch self {
        case .text(let str):
            return [["type": "text", "text": str]]
        case .content(let blocks):
            return blocks.map { $0.toDict() }
        }
    }
}
