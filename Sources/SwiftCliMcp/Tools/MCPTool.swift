import Foundation

// MARK: - Tool Definition

/// Defines an MCP tool that consumers register with the server.
public struct MCPTool: Sendable {
    public let name: String
    public let description: String
    public let inputSchema: MCPSchema
    let handler: @Sendable (AnyCodable) async throws -> MCPToolResult

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
        self.handler = { anyArgs in
            // Encode AnyCodable to JSON Data using shared encoder
            let jsonData = try JSONCoder.encoder.encode(anyArgs)

            // Decode to the typed Arguments using shared decoder
            let typedArgs = try JSONCoder.decoder.decode(Arguments.self, from: jsonData)

            // Call the typed handler
            return try await handler(typedArgs)
        }
    }

    // MARK: - Convenience Initializers

    /// Create a tool without arguments.
    ///
    /// Example:
    /// ```swift
    /// MCPTool(name: "ping", description: "Ping the server") {
    ///     return .text("pong")
    /// }
    /// ```
    public init(
        name: String,
        description: String,
        handler: @escaping @Sendable () async throws -> MCPToolResult
    ) {
        struct NoArgs: Codable {}
        self.init(
            name: name,
            description: description,
            schema: MCPSchema()
        ) { (_: NoArgs) in
            try await handler()
        }
    }

    /// Create a tool with a single string argument.
    ///
    /// Example:
    /// ```swift
    /// MCPTool(
    ///     name: "echo",
    ///     description: "Echo a message",
    ///     argumentName: "message",
    ///     argumentDescription: "The message to echo"
    /// ) { message in
    ///     return .text(message)
    /// }
    /// ```
    public init(
        name: String,
        description: String,
        argumentName: String,
        argumentDescription: String,
        handler: @escaping @Sendable (String) async throws -> MCPToolResult
    ) {
        struct SingleStringArg: Codable {
            let value: String

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                // Try to decode as a string directly first
                if let str = try? container.decode(String.self) {
                    self.value = str
                } else {
                    // Fall back to keyed container with dynamic key
                    let keyedContainer = try decoder.container(keyedBy: DynamicCodingKey.self)
                    let key = keyedContainer.allKeys.first!
                    self.value = try keyedContainer.decode(String.self, forKey: key)
                }
            }

            private struct DynamicCodingKey: CodingKey {
                var stringValue: String
                var intValue: Int?

                init?(stringValue: String) {
                    self.stringValue = stringValue
                    self.intValue = nil
                }

                init?(intValue: Int) {
                    self.stringValue = "\(intValue)"
                    self.intValue = intValue
                }
            }
        }

        self.init(
            name: name,
            description: description,
            schema: MCPSchema(
                properties: [argumentName: .string(argumentDescription)],
                required: [argumentName]
            )
        ) { (args: [String: String]) in
            guard let value = args[argumentName] else {
                throw NSError(
                    domain: "MCPTool",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Missing required argument: \(argumentName)"]
                )
            }
            return try await handler(value)
        }
    }

    /// Build the tool definition for the protocol.
    func toDefinition() -> ToolDefinition {
        return ToolDefinition(
            name: name,
            description: description,
            inputSchema: inputSchema
        )
    }
}
