import Foundation

// MARK: - Response Types

/// Response for initialize request
struct InitializeResponse: Codable, Sendable {
    let protocolVersion: String
    let capabilities: Capabilities
    let serverInfo: ServerInfo

    struct Capabilities: Codable, Sendable {
        let tools: ToolsCapability?
        let resources: ResourcesCapability?
        let prompts: PromptsCapability?
        let logging: LoggingCapability

        struct ToolsCapability: Codable, Sendable {
            let listChanged: Bool
        }

        struct ResourcesCapability: Codable, Sendable {
            let listChanged: Bool
        }

        struct PromptsCapability: Codable, Sendable {
            let listChanged: Bool
        }

        struct LoggingCapability: Codable, Sendable {
            // Empty for now, but structured for future additions
        }
    }

    struct ServerInfo: Codable, Sendable {
        let name: String
        let version: String
        let description: String?
    }
}

/// Response for tools/list request
struct ToolsListResponse: Codable, Sendable {
    let tools: [ToolDefinition]
}

/// Tool definition for protocol
public struct ToolDefinition: Codable, Sendable {
    public let name: String
    public let description: String
    public let inputSchema: MCPSchema
}

/// Response for tools/call request
struct ToolCallResponse: Codable, Sendable {
    let content: [MCPContent]
    let isError: Bool
}

/// Response for resources/list request
struct ResourcesListResponse: Codable, Sendable {
    let resources: [ResourceDefinition]
}

/// Resource definition for protocol
public struct ResourceDefinition: Codable, Sendable {
    public let uri: String
    public let name: String
    public let description: String?
    public let mimeType: String?
}

/// Response for resources/read request
struct ResourcesReadResponse: Codable, Sendable {
    let contents: [ResourceContentsItem]
}

/// Resource contents item for protocol
struct ResourceContentsItem: Codable, Sendable {
    let uri: String
    let mimeType: String?
    let text: String?
    let blob: String? // Base64 encoded

    init(uri: String, mimeType: String?, text: String?, blob: Data?) {
        self.uri = uri
        self.mimeType = mimeType
        self.text = text
        self.blob = blob?.base64EncodedString()
    }
}

/// Response for prompts/list request
struct PromptsListResponse: Codable, Sendable {
    let prompts: [PromptDefinition]
}

/// Prompt definition for protocol
struct PromptDefinition: Codable, Sendable {
    let name: String
    let description: String?
    let arguments: [PromptArgumentDefinition]?
}

/// Prompt argument definition for protocol
struct PromptArgumentDefinition: Codable, Sendable {
    let name: String
    let description: String?
    let required: Bool
}

/// Response for prompts/get request
struct PromptGetResponse: Codable, Sendable {
    let description: String?
    let messages: [PromptMessageItem]
}

/// A single message in a prompt response
struct PromptMessageItem: Codable, Sendable {
    let role: String
    let content: PromptContent

    /// Content within a prompt message (text, image, or embedded resource)
    enum PromptContent: Codable, Sendable {
        case text(String)
        case image(data: String, mimeType: String)
        case resource(uri: String, text: String, mimeType: String?)

        private enum CodingKeys: String, CodingKey {
            case type, text, data, mimeType, uri
        }

        private enum ContentType: String, Codable {
            case text, image, resource
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(ContentType.self, forKey: .type)
            switch type {
            case .text:
                self = .text(try container.decode(String.self, forKey: .text))
            case .image:
                let data = try container.decode(String.self, forKey: .data)
                let mimeType = try container.decode(String.self, forKey: .mimeType)
                self = .image(data: data, mimeType: mimeType)
            case .resource:
                let uri = try container.decode(String.self, forKey: .uri)
                let text = try container.decode(String.self, forKey: .text)
                let mimeType = try container.decodeIfPresent(String.self, forKey: .mimeType)
                self = .resource(uri: uri, text: text, mimeType: mimeType)
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .text(let text):
                try container.encode(ContentType.text, forKey: .type)
                try container.encode(text, forKey: .text)
            case .image(let data, let mimeType):
                try container.encode(ContentType.image, forKey: .type)
                try container.encode(data, forKey: .data)
                try container.encode(mimeType, forKey: .mimeType)
            case .resource(let uri, let text, let mimeType):
                try container.encode(ContentType.resource, forKey: .type)
                try container.encode(uri, forKey: .uri)
                try container.encode(text, forKey: .text)
                try container.encodeIfPresent(mimeType, forKey: .mimeType)
            }
        }
    }
}

// MARK: - Notification Parameters

/// Parameters for notifications/message (logging)
struct LogMessageParams: Codable, Sendable {
    let level: String
    let data: String
    let logger: String?
}

/// Notification for logging
struct LogNotification: Encodable, Sendable {
    let jsonrpc: String = "2.0"
    let method: String = "notifications/message"
    let params: LogMessageParams
}
