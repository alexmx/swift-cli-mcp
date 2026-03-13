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
    /// The schema is auto-generated from the `Arguments` type when not provided
    /// explicitly. Property types are inferred (String → "string", Int → "integer",
    /// Bool → "boolean", Double → "number") and non-optional properties are
    /// marked as required.
    ///
    /// Example:
    /// ```swift
    /// struct GreetArgs: Codable {
    ///     let name: String
    ///     let age: Int?
    /// }
    ///
    /// MCPTool(name: "greet", description: "Greet a user") { (args: GreetArgs) in
    ///     return .text("Hello \(args.name), age \(args.age ?? 0)")
    /// }
    /// ```
    ///
    /// You can provide an explicit schema to override auto-generation:
    /// ```swift
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

        // Auto-generate schema from type if no explicit properties provided
        if schema.properties == nil {
            self.inputSchema = MCPSchema.from(Arguments.self)
        } else {
            self.inputSchema = schema
        }

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

    /// Create a tool with MCPToolInput arguments that have `@InputProperty` annotations.
    ///
    /// Descriptions are automatically extracted from `@InputProperty` wrappers.
    ///
    /// Example:
    /// ```swift
    /// struct EchoArgs: MCPToolInput {
    ///     @InputProperty("The message to echo")
    ///     var message: String
    /// }
    ///
    /// MCPTool(name: "echo", description: "Echo") { (args: EchoArgs) in
    ///     .text(args.message)
    /// }
    /// ```
    public init<Arguments: MCPToolInput>(
        name: String,
        description: String,
        schema: MCPSchema = MCPSchema(),
        handler: @escaping @Sendable (Arguments) async throws -> MCPToolResult
    ) {
        self.name = name
        self.description = description

        if schema.properties == nil {
            self.inputSchema = MCPSchema.from(Arguments.self)
        } else {
            self.inputSchema = schema
        }

        self.handler = { anyArgs in
            let jsonData = try JSONCoder.encoder.encode(anyArgs)
            let typedArgs = try JSONCoder.decoder.decode(Arguments.self, from: jsonData)
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
