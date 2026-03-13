import Foundation

// MARK: - Prompt Definition

/// Represents a prompt template that can be exposed by the MCP server.
public struct MCPPrompt: Sendable {
    public let name: String
    public let description: String?
    public let arguments: [Argument]
    let handler: @Sendable ([String: String]) async throws -> MCPPromptResult

    /// Defines a prompt argument.
    public struct Argument: Sendable {
        public let name: String
        public let description: String?
        public let required: Bool

        public init(name: String, description: String? = nil, required: Bool = false) {
            self.name = name
            self.description = description
            self.required = required
        }
    }

    /// Create a prompt with arguments.
    ///
    /// Example:
    /// ```swift
    /// MCPPrompt(
    ///     name: "code_review",
    ///     description: "Review code for issues",
    ///     arguments: [
    ///         .init(name: "code", description: "The code to review", required: true),
    ///         .init(name: "language", description: "Programming language")
    ///     ]
    /// ) { args in
    ///     let code = args["code"] ?? ""
    ///     return MCPPromptResult(messages: [
    ///         .init(role: .user, content: .text("Review this code:\n\(code)"))
    ///     ])
    /// }
    /// ```
    public init(
        name: String,
        description: String? = nil,
        arguments: [Argument] = [],
        handler: @escaping @Sendable ([String: String]) async throws -> MCPPromptResult
    ) {
        self.name = name
        self.description = description
        self.arguments = arguments
        self.handler = handler
    }

    /// Build the prompt definition for the protocol.
    func toDefinition() -> PromptDefinition {
        PromptDefinition(
            name: name,
            description: description,
            arguments: arguments.isEmpty ? nil : arguments.map {
                PromptArgumentDefinition(
                    name: $0.name,
                    description: $0.description,
                    required: $0.required
                )
            }
        )
    }
}

// MARK: - Prompt Result

/// Result returned by prompt handlers.
public struct MCPPromptResult: Sendable {
    public let description: String?
    public let messages: [Message]

    public init(description: String? = nil, messages: [Message]) {
        self.description = description
        self.messages = messages
    }

    /// A single message in a prompt result.
    public struct Message: Sendable {
        public let role: Role
        public let content: Content

        public init(role: Role, content: Content) {
            self.role = role
            self.content = content
        }

        /// Message role.
        public enum Role: String, Sendable {
            case user
            case assistant
        }

        /// Message content.
        public enum Content: Sendable {
            case text(String)
            case image(data: Data, mimeType: String)
            case resource(uri: String, text: String, mimeType: String?)
        }
    }
}
