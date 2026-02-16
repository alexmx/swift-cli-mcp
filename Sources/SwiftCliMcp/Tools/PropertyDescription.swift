import Foundation

// MARK: - SchemaDefaultValue Protocol

/// Types that can provide a default value for schema extraction.
/// This enables `@PropertyDescription("...")` syntax without requiring a default value.
public protocol SchemaDefaultValue {
    static var schemaDefault: Self { get }
}

extension String: SchemaDefaultValue {
    public static var schemaDefault: String {
        ""
    }
}

extension Bool: SchemaDefaultValue {
    public static var schemaDefault: Bool {
        false
    }
}

extension Int: SchemaDefaultValue {
    public static var schemaDefault: Int {
        0
    }
}

extension Int8: SchemaDefaultValue {
    public static var schemaDefault: Int8 {
        0
    }
}

extension Int16: SchemaDefaultValue {
    public static var schemaDefault: Int16 {
        0
    }
}

extension Int32: SchemaDefaultValue {
    public static var schemaDefault: Int32 {
        0
    }
}

extension Int64: SchemaDefaultValue {
    public static var schemaDefault: Int64 {
        0
    }
}

extension UInt: SchemaDefaultValue {
    public static var schemaDefault: UInt {
        0
    }
}

extension UInt8: SchemaDefaultValue {
    public static var schemaDefault: UInt8 {
        0
    }
}

extension UInt16: SchemaDefaultValue {
    public static var schemaDefault: UInt16 {
        0
    }
}

extension UInt32: SchemaDefaultValue {
    public static var schemaDefault: UInt32 {
        0
    }
}

extension UInt64: SchemaDefaultValue {
    public static var schemaDefault: UInt64 {
        0
    }
}

extension Double: SchemaDefaultValue {
    public static var schemaDefault: Double {
        0
    }
}

extension Float: SchemaDefaultValue {
    public static var schemaDefault: Float {
        0
    }
}

extension Array: SchemaDefaultValue {
    public static var schemaDefault: [Element] {
        []
    }
}

extension Optional: SchemaDefaultValue {
    public static var schemaDefault: Wrapped? {
        nil
    }
}

// MARK: - PropertyDescription Property Wrapper

/// Property wrapper that attaches a description to a Codable property
/// for automatic MCP schema generation.
///
/// Usage:
/// ```swift
/// struct EchoArgs: MCPToolInput {
///     @PropertyDescription("The message to echo")
///     var message: String
/// }
/// ```
@propertyWrapper
public struct PropertyDescription<Value: Codable & Sendable>: Sendable {
    public var wrappedValue: Value
    public let description: String

    /// Initialize with a wrapped value and description.
    public init(wrappedValue: Value, _ description: String) {
        self.wrappedValue = wrappedValue
        self.description = description
    }
}

extension PropertyDescription where Value: SchemaDefaultValue {
    /// Initialize with just a description. The wrapped value uses the type's default.
    /// Enables `@PropertyDescription("msg") var message: String` without `= ""`.
    public init(_ description: String) {
        self.wrappedValue = Value.schemaDefault
        self.description = description
    }
}

// MARK: Codable (transparent)

extension PropertyDescription: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.wrappedValue = try container.decode(Value.self)
        self.description = ""
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

// MARK: Equatable / Hashable

extension PropertyDescription: Equatable where Value: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.wrappedValue == rhs.wrappedValue
    }
}

extension PropertyDescription: Hashable where Value: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(wrappedValue)
    }
}

// MARK: - MCPToolInput Protocol

/// Protocol for tool argument types that support automatic description extraction
/// via `@PropertyDescription` wrappers.
///
/// Conforming types must have a parameterless `init()` so the library can create
/// a default instance and use Mirror to extract descriptions. When all properties
/// use `@PropertyDescription` with `SchemaDefaultValue`-conforming types, `init()`
/// is auto-synthesized.
///
/// ```swift
/// struct EchoArgs: MCPToolInput {
///     @PropertyDescription("The message to echo")
///     var message: String
/// }
/// ```
public protocol MCPToolInput: Codable, Sendable {
    init()
}

// MARK: - Internal Protocols

/// Type-erased protocol for extracting description from PropertyDescription<V>.
protocol PropertyDescribed {
    var propertyDescription: String { get }
}

extension PropertyDescription: PropertyDescribed {
    var propertyDescription: String {
        description
    }
}

/// Protocol for SchemaExtractor to detect PropertyDescription wrappers
/// and get the wrapped type's JSON schema type.
protocol SchemaPropertyWrapper {
    static var wrappedSchemaType: String { get }
    static var wrappedIsOptional: Bool { get }
}

extension PropertyDescription: SchemaPropertyWrapper {
    static var wrappedSchemaType: String {
        if let optionalType = Value.self as? any OptionalProtocol.Type {
            return SchemaTypeMapper.jsonType(for: optionalType.wrappedType)
        }
        return SchemaTypeMapper.jsonType(for: Value.self)
    }

    static var wrappedIsOptional: Bool {
        Value.self is any OptionalProtocol.Type
    }
}

/// Protocol witness for detecting and unwrapping Optional types.
protocol OptionalProtocol {
    static var wrappedType: Any.Type { get }
}

extension Optional: OptionalProtocol {
    static var wrappedType: Any.Type {
        Wrapped.self
    }
}

// MARK: - Description Extraction

/// Extracts @PropertyDescription descriptions from an MCPToolInput type
/// by creating a default instance and inspecting it with Mirror.
enum PropertyDescriptionExtractor {
    static func extractDescriptions<T: MCPToolInput>(from _: T.Type) -> [String: String] {
        let instance = T()
        let mirror = Mirror(reflecting: instance)
        var descriptions: [String: String] = [:]

        for child in mirror.children {
            guard let label = child.label else { continue }
            // Property wrapper storage is prefixed with "_"
            let propertyName = label.hasPrefix("_") ? String(label.dropFirst()) : label

            if let described = child.value as? any PropertyDescribed {
                descriptions[propertyName] = described.propertyDescription
            }
        }

        return descriptions
    }
}
