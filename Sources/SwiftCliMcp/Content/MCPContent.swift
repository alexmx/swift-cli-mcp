import Foundation

// MARK: - Content Types

/// Represents different content types that MCP tools can return.
public enum MCPContent: Codable, Sendable {
    case text(String)
    case image(data: Data, mimeType: String)
    case resource(uri: String, mimeType: String?, text: String?)

    private enum CodingKeys: String, CodingKey {
        case type, text, data, mimeType, uri
    }

    private enum ContentType: String, Codable {
        case text, image, resource
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ContentType.self, forKey: .type)

        switch type {
        case .text:
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
        case .image:
            let dataString = try container.decode(String.self, forKey: .data)
            guard let data = Data(base64Encoded: dataString) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .data,
                    in: container,
                    debugDescription: "Invalid base64 data"
                )
            }
            let mimeType = try container.decode(String.self, forKey: .mimeType)
            self = .image(data: data, mimeType: mimeType)
        case .resource:
            let uri = try container.decode(String.self, forKey: .uri)
            let mimeType = try container.decodeIfPresent(String.self, forKey: .mimeType)
            let text = try container.decodeIfPresent(String.self, forKey: .text)
            self = .resource(uri: uri, mimeType: mimeType, text: text)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .text(let text):
            try container.encode(ContentType.text, forKey: .type)
            try container.encode(text, forKey: .text)
        case .image(let data, let mimeType):
            try container.encode(ContentType.image, forKey: .type)
            try container.encode(data.base64EncodedString(), forKey: .data)
            try container.encode(mimeType, forKey: .mimeType)
        case .resource(let uri, let mimeType, let text):
            try container.encode(ContentType.resource, forKey: .type)
            try container.encode(uri, forKey: .uri)
            try container.encodeIfPresent(mimeType, forKey: .mimeType)
            try container.encodeIfPresent(text, forKey: .text)
        }
    }
}

// MARK: - Tool Result

/// Result returned by tool handlers.
public enum MCPToolResult: Sendable {
    case text(String) // Convenience for single text response
    case content([MCPContent]) // Advanced: multiple content blocks

    /// Convert to MCPContent array
    var contentArray: [MCPContent] {
        switch self {
        case .text(let str):
            return [.text(str)]
        case .content(let blocks):
            return blocks
        }
    }
}
