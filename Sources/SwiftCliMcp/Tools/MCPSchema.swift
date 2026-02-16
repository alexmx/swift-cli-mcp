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

    /// Auto-generate a schema from a Codable type.
    ///
    /// Uses a custom decoder to introspect the type's properties and map them
    /// to JSON Schema types. Non-optional properties are marked as required.
    ///
    /// Supported types: String, Bool, Int (all sizes), Double, Float, arrays,
    /// and nested Codable structs. For complex schemas, use the manual initializer.
    ///
    /// - Parameter type: The Codable type to generate a schema from.
    /// - Returns: An MCPSchema with properties and required fields inferred from the type.
    public static func from<T: Codable>(_ type: T.Type) -> MCPSchema {
        let extractor = SchemaExtractor()
        _ = try? T(from: extractor)
        return MCPSchema(
            properties: extractor.properties,
            required: extractor.required
        )
    }

    /// Auto-generate a schema from an MCPToolInput type, extracting descriptions
    /// from `@InputProperty` wrappers automatically.
    ///
    /// Creates a default instance and uses Mirror to find `@InputProperty`
    /// wrappers and their description strings.
    ///
    /// - Parameter type: The MCPToolInput type to generate a schema from.
    /// - Returns: An MCPSchema with properties, required fields, and descriptions.
    public static func from<T: MCPToolInput>(_ type: T.Type) -> MCPSchema {
        let descriptions = InputPropertyExtractor.extractDescriptions(from: type)
        let extractor = SchemaExtractor(descriptions: descriptions)
        _ = try? T(from: extractor)
        return MCPSchema(
            properties: extractor.properties,
            required: extractor.required
        )
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
