import Foundation

// MARK: - Typed Schema

/// A typed JSON Schema for MCP tool inputs.
public struct MCPSchema: Codable, Sendable {
    public let type: String
    public let properties: [String: MCPProperty]?
    public let required: [String]?

    public init(properties: [String: MCPProperty] = [:], required: [String] = []) {
        self.type = "object"
        self.properties = properties.isEmpty ? nil : properties
        self.required = required.isEmpty ? nil : required
    }

    /// Merge two schemas (for composing shared + tool-specific properties).
    public func merging(_ other: MCPSchema) -> MCPSchema {
        let mergedProperties = (properties ?? [:]).merging(other.properties ?? [:]) { _, new in new }
        let mergedRequired = (required ?? []) + (other.required ?? [])
        return MCPSchema(
            properties: mergedProperties,
            required: mergedRequired
        )
    }
}

// MARK: - Schema Property

/// A single property in an MCP tool schema.
public struct MCPProperty: Codable, Sendable {
    public let type: String
    public let description: String

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
}
