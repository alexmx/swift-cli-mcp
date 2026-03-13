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

    /// Create a text resource with a simplified handler.
    ///
    /// The handler receives the URI and returns a String. The URI and mimeType
    /// are automatically plumbed to `MCPResourceContents`, eliminating duplication.
    public init(
        uri: String,
        name: String,
        description: String? = nil,
        mimeType: String? = nil,
        textHandler: @escaping @Sendable (_ uri: String) async throws -> String
    ) {
        self.uri = uri
        self.name = name
        self.description = description
        self.mimeType = mimeType
        self.handler = {
            MCPResourceContents(uri: uri, text: try await textHandler(uri), mimeType: mimeType)
        }
    }

    /// Create a binary resource with a simplified handler.
    ///
    /// The handler receives the URI and returns Data. The URI and mimeType
    /// are automatically plumbed to `MCPResourceContents`, eliminating duplication.
    public init(
        uri: String,
        name: String,
        description: String? = nil,
        mimeType: String? = nil,
        blobHandler: @escaping @Sendable (_ uri: String) async throws -> Data
    ) {
        self.uri = uri
        self.name = name
        self.description = description
        self.mimeType = mimeType
        self.handler = {
            MCPResourceContents(uri: uri, blob: try await blobHandler(uri), mimeType: mimeType ?? "application/octet-stream")
        }
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

    // MARK: - Static Factories

    /// Create a resource with a full handler returning `MCPResourceContents`.
    public static func resource(
        uri: String,
        name: String,
        description: String? = nil,
        mimeType: String? = nil,
        handler: @escaping @Sendable () async throws -> MCPResourceContents
    ) -> MCPResource {
        MCPResource(uri: uri, name: name, description: description, mimeType: mimeType, handler: handler)
    }

    /// Create a text resource. The handler receives the URI and returns a String.
    public static func textResource(
        uri: String,
        name: String,
        description: String? = nil,
        mimeType: String? = nil,
        handler: @escaping @Sendable (_ uri: String) async throws -> String
    ) -> MCPResource {
        MCPResource(uri: uri, name: name, description: description, mimeType: mimeType, textHandler: handler)
    }

    /// Create a binary resource. The handler receives the URI and returns Data.
    public static func blobResource(
        uri: String,
        name: String,
        description: String? = nil,
        mimeType: String? = nil,
        handler: @escaping @Sendable (_ uri: String) async throws -> Data
    ) -> MCPResource {
        MCPResource(uri: uri, name: name, description: description, mimeType: mimeType, blobHandler: handler)
    }
}

// MARK: - Resource Template

/// Represents a URI template for dynamic resources (RFC 6570).
///
/// Resource templates advertise URI patterns that clients can fill in.
/// When a client reads a resolved URI, the server matches it against
/// registered resources (or a template handler if provided).
///
/// Example:
/// ```swift
/// MCPResourceTemplate(
///     uriTemplate: "file:///{path}",
///     name: "Project Files",
///     description: "Read any file in the project",
///     mimeType: "text/plain"
/// )
/// ```
public struct MCPResourceTemplate: Sendable {
    public let uriTemplate: String
    public let name: String
    public let description: String?
    public let mimeType: String?

    public init(
        uriTemplate: String,
        name: String,
        description: String? = nil,
        mimeType: String? = nil
    ) {
        self.uriTemplate = uriTemplate
        self.name = name
        self.description = description
        self.mimeType = mimeType
    }

    /// Build the template definition for the protocol.
    func toDefinition() -> ResourceTemplateDefinition {
        ResourceTemplateDefinition(
            uriTemplate: uriTemplate,
            name: name,
            description: description,
            mimeType: mimeType
        )
    }

    /// Create a resource template.
    public static func template(
        uriTemplate: String,
        name: String,
        description: String? = nil,
        mimeType: String? = nil
    ) -> MCPResourceTemplate {
        MCPResourceTemplate(uriTemplate: uriTemplate, name: name, description: description, mimeType: mimeType)
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
