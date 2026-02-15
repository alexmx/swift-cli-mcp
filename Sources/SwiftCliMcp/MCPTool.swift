import Foundation

/// Defines an MCP tool that consumers register with the server.
public struct MCPTool: Sendable {
    public let name: String
    public let description: String
    let inputSchema: MCPSchema?
    /// JSON Schema for tool input, stored as raw JSON bytes (legacy string-based init).
    let inputSchemaData: Data
    public let handler: @Sendable ([String: Any]) async throws -> String

    /// Create a tool with a typed schema.
    ///
    /// Example:
    /// ```swift
    /// MCPTool(
    ///     name: "greet",
    ///     description: "Say hello",
    ///     schema: MCPSchema(
    ///         properties: ["name": .string("Name to greet")],
    ///         required: ["name"]
    ///     )
    /// ) { args in "Hello, \(args["name"] ?? "world")!" }
    /// ```
    public init(
        name: String,
        description: String,
        schema: MCPSchema = MCPSchema(),
        handler: @escaping @Sendable ([String: Any]) async throws -> String
    ) {
        self.name = name
        self.description = description
        self.inputSchema = schema
        self.inputSchemaData = Data()
        self.handler = handler
    }

    /// Create a tool with an input schema defined as a JSON string.
    public init(
        name: String,
        description: String,
        schema: String,
        handler: @escaping @Sendable ([String: Any]) async throws -> String
    ) {
        self.name = name
        self.description = description
        self.inputSchema = nil
        self.inputSchemaData = Data(schema.utf8)
        self.handler = handler
    }

    /// Build the tool definition dict for the tools/list response.
    func definition() -> [String: Any] {
        let schema: [String: Any]
        if let inputSchema {
            schema = inputSchema.toDict()
        } else {
            var parsed: [String: Any] = ["type": "object"]
            if let dict = try? JSONSerialization.jsonObject(with: inputSchemaData) as? [String: Any] {
                if let props = dict["properties"] {
                    parsed["properties"] = props
                }
                if let required = dict["required"] {
                    parsed["required"] = required
                }
            }
            schema = parsed
        }

        return [
            "name": name,
            "description": description,
            "inputSchema": schema,
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
