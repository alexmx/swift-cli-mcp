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

        /// Create a required argument.
        public static func required(name: String, description: String? = nil) -> Argument {
            Argument(name: name, description: description, required: true)
        }

        /// Create an optional argument.
        public static func optional(name: String, description: String? = nil) -> Argument {
            Argument(name: name, description: description, required: false)
        }
    }

    /// Create a prompt with arguments.
    ///
    /// Example:
    /// ```swift
    /// .prompt(
    ///     name: "code_review",
    ///     description: "Review code for issues",
    ///     arguments: [
    ///         .required(name: "code", description: "The code to review"),
    ///         .optional(name: "language", description: "Programming language")
    ///     ]
    /// ) { args in
    ///     .userMessage("Review this code:\n\(args["code"] ?? "")")
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

    /// Create a prompt.
    public static func prompt(
        name: String,
        description: String? = nil,
        arguments: [Argument] = [],
        handler: @escaping @Sendable ([String: String]) async throws -> MCPPromptResult
    ) -> MCPPrompt {
        MCPPrompt(name: name, description: description, arguments: arguments, handler: handler)
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

    /// Create a result with multiple messages.
    public static func result(description: String? = nil, messages: [Message]) -> MCPPromptResult {
        MCPPromptResult(description: description, messages: messages)
    }

    /// Create a result with a single user text message.
    public static func userMessage(_ text: String, description: String? = nil) -> MCPPromptResult {
        MCPPromptResult(description: description, messages: [.user(text)])
    }

    /// Create a result with a single assistant text message.
    public static func assistantMessage(_ text: String, description: String? = nil) -> MCPPromptResult {
        MCPPromptResult(description: description, messages: [.assistant(text)])
    }

    /// A single message in a prompt result.
    public struct Message: Sendable {
        public let role: Role
        public let content: MCPContent

        public init(role: Role, content: MCPContent) {
            self.role = role
            self.content = content
        }

        /// Create a user message with text content.
        public static func user(_ text: String) -> Message {
            Message(role: .user, content: .text(text))
        }

        /// Create an assistant message with text content.
        public static func assistant(_ text: String) -> Message {
            Message(role: .assistant, content: .text(text))
        }

        /// Create a user message with any content type.
        public static func user(_ content: MCPContent) -> Message {
            Message(role: .user, content: content)
        }

        /// Create an assistant message with any content type.
        public static func assistant(_ content: MCPContent) -> Message {
            Message(role: .assistant, content: content)
        }

        /// Message role.
        public enum Role: String, Sendable {
            case user
            case assistant
        }
    }
}
