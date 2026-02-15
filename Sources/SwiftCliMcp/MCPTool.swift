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

// MARK: - Tool Definition

/// Defines an MCP tool that consumers register with the server.
public struct MCPTool: Sendable {
    public let name: String
    public let description: String
    public let inputSchema: MCPSchema
    let handler: @Sendable ([String: Any]) async throws -> MCPToolResult

    /// Create a tool with strongly-typed Codable arguments.
    ///
    /// Example:
    /// ```swift
    /// struct GreetArgs: Codable {
    ///     let name: String
    ///     let age: Int?
    /// }
    ///
    /// MCPTool(
    ///     name: "greet",
    ///     description: "Greet a user",
    ///     schema: MCPSchema(
    ///         properties: [
    ///             "name": .string("User's name"),
    ///             "age": .integer("User's age")
    ///         ],
    ///         required: ["name"]
    ///     )
    /// ) { (args: GreetArgs) in
    ///     return .text("Hello \(args.name), age \(args.age ?? 0)")
    /// }
    /// ```
    public init<Arguments: Codable>(
        name: String,
        description: String,
        schema: MCPSchema = MCPSchema(),
        handler: @escaping @Sendable (Arguments) async throws -> MCPToolResult
    ) {
        self.name = name
        self.description = description
        self.inputSchema = schema

        // Wrap the typed handler to decode arguments
        self.handler = { untypedArgs in
            // Convert [String: Any] to JSON Data
            let jsonData = try JSONSerialization.data(withJSONObject: untypedArgs)

            // Decode to the typed Arguments
            let decoder = JSONDecoder()
            let typedArgs = try decoder.decode(Arguments.self, from: jsonData)

            // Call the typed handler
            return try await handler(typedArgs)
        }
    }

    /// Build the tool definition dict for the tools/list response.
    func definition() -> [String: Any] {
        return [
            "name": name,
            "description": description,
            "inputSchema": inputSchema.toDict()
        ]
    }
}

// MARK: - Typed Schema

/// A typed JSON Schema for MCP tool inputs.
public struct MCPSchema: Sendable {
    public let properties: [String: MCPProperty]
    public let required: [String]

    public init(properties: [String: MCPProperty] = [:], required: [String] = []) {
        self.properties = properties
        self.required = required
    }

    /// Merge two schemas (for composing shared + tool-specific properties).
    public func merging(_ other: MCPSchema) -> MCPSchema {
        MCPSchema(
            properties: properties.merging(other.properties) { _, new in new },
            required: required + other.required
        )
    }

    func toDict() -> [String: Any] {
        var dict: [String: Any] = ["type": "object"]
        if !properties.isEmpty {
            dict["properties"] = properties.mapValues { $0.toDict() }
        }
        if !required.isEmpty {
            dict["required"] = required
        }
        return dict
    }
}

/// A single property in an MCP tool schema.
public struct MCPProperty: Sendable {
    let type: String
    let description: String

    public static func string(_ description: String) -> MCPProperty {
        MCPProperty(type: "string", description: description)
    }

    public static func integer(_ description: String) -> MCPProperty {
        MCPProperty(type: "integer", description: description)
    }

    public static func boolean(_ description: String) -> MCPProperty {
        MCPProperty(type: "boolean", description: description)
    }

    public static func number(_ description: String) -> MCPProperty {
        MCPProperty(type: "number", description: description)
    }

    func toDict() -> [String: Any] {
        ["type": type, "description": description]
    }
}

// MARK: - Resources

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
