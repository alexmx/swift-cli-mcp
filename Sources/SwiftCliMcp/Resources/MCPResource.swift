import Foundation

// MARK: - Resource Definition

/// Represents a resource that can be exposed by the MCP server.
public struct MCPResource: Sendable {
    public let uri: String
    public let name: String
    public let description: String?
    public let mimeType: String?
    public let handler: @Sendable () async throws -> MCPResourceContents

    public init(
        uri: String,
        name: String,
        description: String? = nil,
        mimeType: String? = nil,
        handler: @escaping @Sendable () async throws -> MCPResourceContents
    ) {
        self.uri = uri
        self.name = name
        self.description = description
        self.mimeType = mimeType
        self.handler = handler
    }

    /// Build the resource definition for the protocol.
    func toDefinition() -> ResourceDefinition {
        return ResourceDefinition(
            uri: uri,
            name: name,
            description: description,
            mimeType: mimeType
        )
    }
}

// MARK: - Resource Contents

/// Contents returned by resource handlers.
public struct MCPResourceContents: Sendable {
    public let uri: String
    public let mimeType: String?
    public let text: String?
    public let blob: Data?

    public init(uri: String, text: String, mimeType: String? = "text/plain") {
        self.uri = uri
        self.text = text
        self.blob = nil
        self.mimeType = mimeType
    }

    public init(uri: String, blob: Data, mimeType: String) {
        self.uri = uri
        self.text = nil
        self.blob = blob
        self.mimeType = mimeType
    }

    /// Convert to protocol ResourceContentsItem.
    func toProtocolItem() -> ResourceContentsItem {
        return ResourceContentsItem(
            uri: uri,
            mimeType: mimeType,
            text: text,
            blob: blob
        )
    }
}
