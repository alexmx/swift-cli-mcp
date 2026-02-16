import Foundation

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
