import Foundation
@testable import SwiftMCP
import Testing

@Suite("Schema and Tool")
struct SchemaTests {
    // MARK: - Typed Schema Tests

    @Test("Empty schema")
    func emptySchema() throws {
        let schema = MCPSchema()

        // Test Codable conformance
        let encoder = JSONEncoder()
        let data = try encoder.encode(schema)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MCPSchema.self, from: data)

        #expect(decoded.type == "object")
        #expect(decoded.properties == nil)
        #expect(decoded.required == nil)
    }

    @Test("Schema with properties")
    func schemaWithProperties() throws {
        let schema = MCPSchema(
            properties: [
                "name": .string("User name"),
                "age": .integer("User age")
            ],
            required: ["name"]
        )

        // Test Codable conformance
        let encoder = JSONEncoder()
        let data = try encoder.encode(schema)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MCPSchema.self, from: data)

        #expect(decoded.type == "object")
        #expect(decoded.properties?.count == 2)
        #expect(decoded.properties?["name"]?.type == "string")
        #expect(decoded.properties?["age"]?.type == "integer")
        #expect(decoded.required == ["name"])
    }

    @Test("Schema merging")
    func schemaMerging() {
        let base = MCPSchema(
            properties: ["a": .string("A")],
            required: ["a"]
        )
        let extra = MCPSchema(
            properties: ["b": .number("B")],
            required: ["b"]
        )

        let merged = base.merging(extra)

        #expect(merged.properties?.keys.count == 2)
        #expect(merged.properties?["a"] != nil)
        #expect(merged.properties?["b"] != nil)
        #expect(merged.required?.count == 2)
        #expect(merged.required?.contains("a") == true)
        #expect(merged.required?.contains("b") == true)
    }

    // MARK: - Property Tests

    @Test("String property")
    func stringProperty() throws {
        let prop = MCPProperty.string("A string field")

        // Test Codable conformance
        let encoder = JSONEncoder()
        let data = try encoder.encode(prop)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MCPProperty.self, from: data)

        #expect(decoded.type == "string")
        #expect(decoded.description == "A string field")
    }

    @Test("All property types")
    func allPropertyTypes() throws {
        let types: [(MCPProperty, String)] = [
            (.string("str"), "string"),
            (.integer("int"), "integer"),
            (.boolean("bool"), "boolean"),
            (.number("num"), "number")
        ]

        for (prop, expectedType) in types {
            let encoder = JSONEncoder()
            let data = try encoder.encode(prop)
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(MCPProperty.self, from: data)
            #expect(decoded.type == expectedType)
        }
    }

    // MARK: - Tool Tests

    @Test("Tool definition")
    func toolDefinition() {
        struct TestArgs: Codable {
            let input: String
        }

        let tool = MCPTool(
            name: "test",
            description: "Test tool",
            schema: MCPSchema(
                properties: ["input": .string("Input value")],
                required: ["input"]
            )
        ) { (args: TestArgs) in .text("result") }

        let def = tool.toDefinition()
        #expect(def.name == "test")
        #expect(def.description == "Test tool")
        #expect(def.inputSchema.type == "object")
        #expect(def.inputSchema.properties?["input"]?.type == "string")
    }

    // MARK: - Typed Arguments Tests

    @Test("Tool with typed Codable arguments")
    func toolWithTypedArguments() async throws {
        struct GreetArgs: Codable {
            let name: String
            let age: Int?
        }

        let tool = MCPTool(
            name: "greet",
            description: "Greet user",
            schema: MCPSchema(
                properties: [
                    "name": .string("User's name"),
                    "age": .integer("User's age")
                ],
                required: ["name"]
            )
        ) { (args: GreetArgs) in
            let ageStr = args.age.map { " age \($0)" } ?? ""
            return .text("Hello \(args.name)\(ageStr)")
        }

        // Test with all fields
        let result1 = try await tool.handler(AnyCodable(["name": "Alice", "age": 30] as [String: Any]))
        guard case .text(let text1) = result1 else {
            Issue.record("Expected text result")
            return
        }
        #expect(text1 == "Hello Alice age 30")

        // Test with optional field missing
        let result2 = try await tool.handler(AnyCodable(["name": "Bob"] as [String: Any]))
        guard case .text(let text2) = result2 else {
            Issue.record("Expected text result")
            return
        }
        #expect(text2 == "Hello Bob")
    }

    @Test("Typed tool validates argument types")
    func typedToolValidation() async throws {
        struct StrictArgs: Codable {
            let count: Int
        }

        let tool = MCPTool(
            name: "count",
            description: "Count",
            schema: MCPSchema(
                properties: ["count": .integer("Count")],
                required: ["count"]
            )
        ) { (args: StrictArgs) in
            return .text("Count: \(args.count)")
        }

        // Valid argument
        let result = try await tool.handler(AnyCodable(["count": 42] as [String: Any]))
        guard case .text(let text) = result else {
            Issue.record("Expected text result")
            return
        }
        #expect(text == "Count: 42")

        // Invalid type should throw
        do {
            _ = try await tool.handler(AnyCodable(["count": "not a number"] as [String: Any]))
            Issue.record("Should have thrown decoding error")
        } catch {
            // Expected - decoding error
            #expect(error is DecodingError)
        }
    }

    @Test("Typed tool with missing required field")
    func typedToolMissingRequired() async throws {
        struct RequiredArgs: Codable {
            let required: String
        }

        let tool = MCPTool(
            name: "test",
            description: "Test",
            schema: MCPSchema(
                properties: ["required": .string("Required field")],
                required: ["required"]
            )
        ) { (args: RequiredArgs) in
            return .text(args.required)
        }

        // Missing required field should throw
        do {
            _ = try await tool.handler(AnyCodable([:] as [String: Any]))
            Issue.record("Should have thrown decoding error")
        } catch {
            #expect(error is DecodingError)
        }
    }

    @Test("Typed tool with nested structures")
    func typedToolNested() async throws {
        struct Address: Codable {
            let street: String
            let city: String
        }

        struct UserArgs: Codable {
            let name: String
            let address: Address
        }

        let tool = MCPTool(
            name: "register",
            description: "Register user"
        ) { (args: UserArgs) in
            return .text("\(args.name) from \(args.address.city)")
        }

        let result = try await tool.handler(AnyCodable([
            "name": "Alice",
            "address": [
                "street": "123 Main St",
                "city": "Springfield"
            ]
        ] as [String: Any]))

        guard case .text(let text) = result else {
            Issue.record("Expected text result")
            return
        }
        #expect(text == "Alice from Springfield")
    }
}
