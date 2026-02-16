import Foundation

// MARK: - Request Parameters

/// Parameters for tools/call request
struct ToolCallParams: Codable, Sendable {
    let name: String
    let arguments: [String: AnyCodable]?
}

/// Parameters for resources/read request
struct ResourceReadParams: Codable, Sendable {
    let uri: String
}

// MARK: - Response Types

/// Response for initialize request
struct InitializeResponse: Codable, Sendable {
    let protocolVersion: String
    let capabilities: Capabilities
    let serverInfo: ServerInfo

    struct Capabilities: Codable, Sendable {
        let tools: ToolsCapability?
        let resources: ResourcesCapability?
        let logging: LoggingCapability

        struct ToolsCapability: Codable, Sendable {
            let listChanged: Bool
        }

        struct ResourcesCapability: Codable, Sendable {
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

// MARK: - Notification Parameters

/// Parameters for notifications/message (logging)
struct LogMessageParams: Codable, Sendable {
    let level: String
    let data: String
    let logger: String?
}

/// Notification for logging
struct LogNotification: Codable, Sendable {
    let jsonrpc: String = "2.0"
    let method: String = "notifications/message"
    let params: LogMessageParams
}
