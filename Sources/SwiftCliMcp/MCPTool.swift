import Foundation

/// Defines an MCP tool that consumers register with the server.
public struct MCPTool: Sendable {
    public let name: String
    public let description: String
    /// JSON Schema for tool input, stored as raw JSON bytes.
    let inputSchemaData: Data
    public let handler: @Sendable ([String: Any]) async throws -> String

    /// Create a tool with an input schema defined as a JSON string.
    ///
    /// Example:
    /// ```swift
    /// MCPTool(
    ///     name: "greet",
    ///     description: "Say hello",
    ///     schema: """
    ///     {
    ///         "properties": {
    ///             "name": { "type": "string", "description": "Name to greet" }
    ///         },
    ///         "required": ["name"]
    ///     }
    ///     """,
    ///     handler: { args in "Hello, \(args["name"] ?? "world")!" }
    /// )
    /// ```
    public init(
        name: String,
        description: String,
        schema: String = "{}",
        handler: @escaping @Sendable ([String: Any]) async throws -> String
    ) {
        self.name = name
        self.description = description
        self.inputSchemaData = Data(schema.utf8)
        self.handler = handler
    }

    /// Build the tool definition dict for the tools/list response.
    func definition() -> [String: Any] {
        var schema: [String: Any] = ["type": "object"]
        if let parsed = try? JSONSerialization.jsonObject(with: inputSchemaData) as? [String: Any] {
            if let props = parsed["properties"] {
                schema["properties"] = props
            }
            if let required = parsed["required"] {
                schema["required"] = required
            }
        }

        return [
            "name": name,
            "description": description,
            "inputSchema": schema,
        ]
    }
}
