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

    func definition() -> [String: Any] {
        var dict: [String: Any] = [
            "uri": uri,
            "name": name
        ]
        if let description { dict["description"] = description }
        if let mimeType { dict["mimeType"] = mimeType }
        return dict
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

    func toDict() -> [String: Any] {
        var dict: [String: Any] = ["uri": uri]
        if let mimeType { dict["mimeType"] = mimeType }
        if let text {
            dict["text"] = text
        } else if let blob {
            dict["blob"] = blob.base64EncodedString()
        }
        return dict
    }
}
