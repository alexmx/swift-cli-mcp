import Foundation

// MARK: - Schema Extractor

/// Custom Decoder that extracts JSON Schema information from a Codable type
/// by observing how it decodes its properties. Records property names, JSON types,
/// and whether each property is required (decode) or optional (decodeIfPresent).
final class SchemaExtractor: Decoder {
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any] = [:]

    var properties: [String: MCPProperty] = [:]
    var required: [String] = []
    let descriptions: [String: String]

    init(descriptions: [String: String] = [:], codingPath: [CodingKey] = []) {
        self.descriptions = descriptions
        self.codingPath = codingPath
    }

    func container<Key: CodingKey>(keyedBy _: Key.Type) throws -> KeyedDecodingContainer<Key> {
        KeyedDecodingContainer(SchemaKeyedContainer<Key>(extractor: self, codingPath: codingPath))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        SchemaUnkeyedContainer(codingPath: codingPath)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        SchemaSingleValueContainer(codingPath: codingPath)
    }
}

// MARK: - Type Mapper

enum SchemaTypeMapper {
    static func jsonType(for type: (some Any).Type) -> String {
        switch type {
        case is String.Type: return "string"
        case is Bool.Type: return "boolean"
        case is Int.Type, is Int8.Type, is Int16.Type, is Int32.Type, is Int64.Type,
             is UInt.Type, is UInt8.Type, is UInt16.Type, is UInt32.Type, is UInt64.Type:
            return "integer"
        case is Double.Type, is Float.Type: return "number"
        default:
            let name = String(describing: type)
            if name.hasPrefix("Array<") {
                return "array"
            } else {
                return "object"
            }
        }
    }
}

// MARK: - Keyed Container

private struct SchemaKeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let extractor: SchemaExtractor
    var codingPath: [CodingKey]
    var allKeys: [Key] = []

    private func desc(for key: Key) -> String {
        extractor.descriptions[key.stringValue] ?? key.stringValue
    }

    private func record(_ key: Key, jsonType: String) {
        extractor.properties[key.stringValue] = MCPProperty(type: jsonType, description: desc(for: key))
        extractor.required.append(key.stringValue)
    }

    private func recordOptional(_ key: Key, jsonType: String) {
        extractor.properties[key.stringValue] = MCPProperty(type: jsonType, description: desc(for: key))
    }

    func contains(_: Key) -> Bool {
        true
    }

    func decodeNil(forKey _: Key) throws -> Bool {
        true
    }

    // MARK: Required Primitives

    func decode(_: Bool.Type, forKey key: Key) throws -> Bool {
        record(key, jsonType: "boolean"); return false
    }

    func decode(_: String.Type, forKey key: Key) throws -> String {
        record(key, jsonType: "string"); return ""
    }

    func decode(_: Double.Type, forKey key: Key) throws -> Double {
        record(key, jsonType: "number"); return 0
    }

    func decode(_: Float.Type, forKey key: Key) throws -> Float {
        record(key, jsonType: "number"); return 0
    }

    func decode(_: Int.Type, forKey key: Key) throws -> Int {
        record(key, jsonType: "integer"); return 0
    }

    func decode(_: Int8.Type, forKey key: Key) throws -> Int8 {
        record(key, jsonType: "integer"); return 0
    }

    func decode(_: Int16.Type, forKey key: Key) throws -> Int16 {
        record(key, jsonType: "integer"); return 0
    }

    func decode(_: Int32.Type, forKey key: Key) throws -> Int32 {
        record(key, jsonType: "integer"); return 0
    }

    func decode(_: Int64.Type, forKey key: Key) throws -> Int64 {
        record(key, jsonType: "integer"); return 0
    }

    func decode(_: UInt.Type, forKey key: Key) throws -> UInt {
        record(key, jsonType: "integer"); return 0
    }

    func decode(_: UInt8.Type, forKey key: Key) throws -> UInt8 {
        record(key, jsonType: "integer"); return 0
    }

    func decode(_: UInt16.Type, forKey key: Key) throws -> UInt16 {
        record(key, jsonType: "integer"); return 0
    }

    func decode(_: UInt32.Type, forKey key: Key) throws -> UInt32 {
        record(key, jsonType: "integer"); return 0
    }

    func decode(_: UInt64.Type, forKey key: Key) throws -> UInt64 {
        record(key, jsonType: "integer"); return 0
    }

    // MARK: Generic Required Decode

    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        // Detect @PropertyDescription wrapper and use the wrapped type's JSON type
        if let wrapperType = type as? any SchemaPropertyWrapper.Type {
            let jsonType = wrapperType.wrappedSchemaType
            if wrapperType.wrappedIsOptional {
                recordOptional(key, jsonType: jsonType)
            } else {
                record(key, jsonType: jsonType)
            }
        } else {
            let jsonType = SchemaTypeMapper.jsonType(for: type)
            record(key, jsonType: jsonType)
        }

        // Try to create a dummy instance via recursive extraction
        let subExtractor = SchemaExtractor(
            descriptions: extractor.descriptions,
            codingPath: codingPath + [key]
        )
        if let value = try? T(from: subExtractor) {
            return value
        }

        // Try common JSON representations
        for json in ["\"\"", "0", "false", "[]", "{}"] {
            if let value = try? JSONCoder.decoder.decode(T.self, from: Data(json.utf8)) {
                return value
            }
        }

        throw SchemaExtractionError.unsupportedType
    }

    // MARK: Optional Primitives

    func decodeIfPresent(_: Bool.Type, forKey key: Key) throws -> Bool? {
        recordOptional(key, jsonType: "boolean"); return nil
    }

    func decodeIfPresent(_: String.Type, forKey key: Key) throws -> String? {
        recordOptional(key, jsonType: "string"); return nil
    }

    func decodeIfPresent(_: Double.Type, forKey key: Key) throws -> Double? {
        recordOptional(key, jsonType: "number"); return nil
    }

    func decodeIfPresent(_: Float.Type, forKey key: Key) throws -> Float? {
        recordOptional(key, jsonType: "number"); return nil
    }

    func decodeIfPresent(_: Int.Type, forKey key: Key) throws -> Int? {
        recordOptional(key, jsonType: "integer"); return nil
    }

    func decodeIfPresent(_: Int8.Type, forKey key: Key) throws -> Int8? {
        recordOptional(key, jsonType: "integer"); return nil
    }

    func decodeIfPresent(_: Int16.Type, forKey key: Key) throws -> Int16? {
        recordOptional(key, jsonType: "integer"); return nil
    }

    func decodeIfPresent(_: Int32.Type, forKey key: Key) throws -> Int32? {
        recordOptional(key, jsonType: "integer"); return nil
    }

    func decodeIfPresent(_: Int64.Type, forKey key: Key) throws -> Int64? {
        recordOptional(key, jsonType: "integer"); return nil
    }

    func decodeIfPresent(_: UInt.Type, forKey key: Key) throws -> UInt? {
        recordOptional(key, jsonType: "integer"); return nil
    }

    func decodeIfPresent(_: UInt8.Type, forKey key: Key) throws -> UInt8? {
        recordOptional(key, jsonType: "integer"); return nil
    }

    func decodeIfPresent(_: UInt16.Type, forKey key: Key) throws -> UInt16? {
        recordOptional(key, jsonType: "integer"); return nil
    }

    func decodeIfPresent(_: UInt32.Type, forKey key: Key) throws -> UInt32? {
        recordOptional(key, jsonType: "integer"); return nil
    }

    func decodeIfPresent(_: UInt64.Type, forKey key: Key) throws -> UInt64? {
        recordOptional(key, jsonType: "integer"); return nil
    }

    // MARK: Generic Optional Decode

    func decodeIfPresent<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T? {
        // Detect @PropertyDescription wrapper and use the wrapped type's JSON type
        if let wrapperType = type as? any SchemaPropertyWrapper.Type {
            recordOptional(key, jsonType: wrapperType.wrappedSchemaType)
        } else {
            let jsonType = SchemaTypeMapper.jsonType(for: type)
            recordOptional(key, jsonType: jsonType)
        }
        return nil
    }

    // MARK: Nested Containers

    func nestedContainer<NestedKey: CodingKey>(
        keyedBy _: NestedKey.Type,
        forKey key: Key
    ) throws -> KeyedDecodingContainer<NestedKey> {
        let sub = SchemaExtractor(codingPath: codingPath + [key])
        return KeyedDecodingContainer(SchemaKeyedContainer<NestedKey>(extractor: sub, codingPath: codingPath + [key]))
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        SchemaUnkeyedContainer(codingPath: codingPath + [key])
    }

    func superDecoder() throws -> Decoder {
        SchemaExtractor(codingPath: codingPath)
    }

    func superDecoder(forKey key: Key) throws -> Decoder {
        SchemaExtractor(codingPath: codingPath + [key])
    }
}

// MARK: - Unkeyed Container (arrays decode as empty)

private struct SchemaUnkeyedContainer: UnkeyedDecodingContainer {
    var codingPath: [CodingKey]
    var count: Int? = 0
    var isAtEnd: Bool = true
    var currentIndex: Int = 0

    mutating func decodeNil() throws -> Bool {
        true
    }

    mutating func decode(_: Bool.Type) throws -> Bool {
        false
    }

    mutating func decode(_: String.Type) throws -> String {
        ""
    }

    mutating func decode(_: Double.Type) throws -> Double {
        0
    }

    mutating func decode(_: Float.Type) throws -> Float {
        0
    }

    mutating func decode(_: Int.Type) throws -> Int {
        0
    }

    mutating func decode(_: Int8.Type) throws -> Int8 {
        0
    }

    mutating func decode(_: Int16.Type) throws -> Int16 {
        0
    }

    mutating func decode(_: Int32.Type) throws -> Int32 {
        0
    }

    mutating func decode(_: Int64.Type) throws -> Int64 {
        0
    }

    mutating func decode(_: UInt.Type) throws -> UInt {
        0
    }

    mutating func decode(_: UInt8.Type) throws -> UInt8 {
        0
    }

    mutating func decode(_: UInt16.Type) throws -> UInt16 {
        0
    }

    mutating func decode(_: UInt32.Type) throws -> UInt32 {
        0
    }

    mutating func decode(_: UInt64.Type) throws -> UInt64 {
        0
    }

    mutating func decode<T: Decodable>(_: T.Type) throws -> T {
        throw SchemaExtractionError.unsupportedType
    }

    mutating func nestedContainer<NestedKey: CodingKey>(
        keyedBy _: NestedKey.Type
    ) throws -> KeyedDecodingContainer<NestedKey> {
        throw SchemaExtractionError.unsupportedType
    }

    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        SchemaUnkeyedContainer(codingPath: codingPath)
    }

    mutating func superDecoder() throws -> Decoder {
        SchemaExtractor(codingPath: codingPath)
    }
}

// MARK: - Single Value Container

private struct SchemaSingleValueContainer: SingleValueDecodingContainer {
    var codingPath: [CodingKey]

    func decodeNil() -> Bool {
        true
    }

    func decode(_: Bool.Type) throws -> Bool {
        false
    }

    func decode(_: String.Type) throws -> String {
        ""
    }

    func decode(_: Double.Type) throws -> Double {
        0
    }

    func decode(_: Float.Type) throws -> Float {
        0
    }

    func decode(_: Int.Type) throws -> Int {
        0
    }

    func decode(_: Int8.Type) throws -> Int8 {
        0
    }

    func decode(_: Int16.Type) throws -> Int16 {
        0
    }

    func decode(_: Int32.Type) throws -> Int32 {
        0
    }

    func decode(_: Int64.Type) throws -> Int64 {
        0
    }

    func decode(_: UInt.Type) throws -> UInt {
        0
    }

    func decode(_: UInt8.Type) throws -> UInt8 {
        0
    }

    func decode(_: UInt16.Type) throws -> UInt16 {
        0
    }

    func decode(_: UInt32.Type) throws -> UInt32 {
        0
    }

    func decode(_: UInt64.Type) throws -> UInt64 {
        0
    }

    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        let sub = SchemaExtractor(codingPath: codingPath)
        if let value = try? T(from: sub) {
            return value
        }
        throw SchemaExtractionError.unsupportedType
    }
}

// MARK: - Error

private enum SchemaExtractionError: Error {
    case unsupportedType
}
