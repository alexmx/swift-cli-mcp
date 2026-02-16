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

    // MARK: - Schema Auto-Generation Tests

    @Test("Auto-generate schema from Codable type")
    func autoGenerateSchema() {
        struct UserArgs: Codable {
            let name: String
            let age: Int
            let active: Bool
            let score: Double
        }

        let schema = MCPSchema.from(UserArgs.self)

        #expect(schema.type == "object")
        #expect(schema.properties?.count == 4)
        #expect(schema.properties?["name"]?.type == "string")
        #expect(schema.properties?["age"]?.type == "integer")
        #expect(schema.properties?["active"]?.type == "boolean")
        #expect(schema.properties?["score"]?.type == "number")
        #expect(schema.required?.count == 4)
        #expect(schema.required?.contains("name") == true)
        #expect(schema.required?.contains("age") == true)
    }

    @Test("Auto-generate schema with optional properties")
    func autoGenerateOptional() {
        struct SearchArgs: Codable {
            let query: String
            let limit: Int?
            let verbose: Bool?
        }

        let schema = MCPSchema.from(SearchArgs.self)

        #expect(schema.properties?.count == 3)
        #expect(schema.properties?["query"]?.type == "string")
        #expect(schema.properties?["limit"]?.type == "integer")
        #expect(schema.properties?["verbose"]?.type == "boolean")
        // Only query should be required
        #expect(schema.required == ["query"])
    }

    @Test("Auto-generate schema with custom descriptions")
    func autoGenerateDescriptions() {
        struct EchoArgs: Codable {
            let message: String
        }

        let schema = MCPSchema.from(
            EchoArgs.self,
            descriptions: ["message": "The message to echo"]
        )

        #expect(schema.properties?["message"]?.description == "The message to echo")
    }

    @Test("Auto-generate schema defaults description to property name")
    func autoGenerateDefaultDescription() {
        struct SimpleArgs: Codable {
            let name: String
        }

        let schema = MCPSchema.from(SimpleArgs.self)
        #expect(schema.properties?["name"]?.description == "name")
    }

    @Test("Auto-generate schema from empty type")
    func autoGenerateEmpty() {
        struct NoArgs: Codable {}

        let schema = MCPSchema.from(NoArgs.self)
        #expect(schema.properties == nil)
        #expect(schema.required == nil)
    }

    @Test("Auto-generate schema with array property")
    func autoGenerateArray() {
        struct TagArgs: Codable {
            let name: String
            let tags: [String]?
        }

        let schema = MCPSchema.from(TagArgs.self)
        #expect(schema.properties?["name"]?.type == "string")
        #expect(schema.properties?["tags"]?.type == "array")
        #expect(schema.required == ["name"])
    }

    @Test("MCPTool auto-generates schema when none provided")
    func toolAutoSchema() {
        struct GreetArgs: Codable {
            let name: String
            let age: Int?
        }

        let tool = MCPTool(
            name: "greet",
            description: "Greet user"
        ) { (args: GreetArgs) in
            .text("Hello \(args.name)")
        }

        let def = tool.toDefinition()
        #expect(def.inputSchema.properties?["name"]?.type == "string")
        #expect(def.inputSchema.properties?["age"]?.type == "integer")
        #expect(def.inputSchema.required == ["name"])
    }

    @Test("MCPTool with propertyDescriptions")
    func toolPropertyDescriptions() {
        struct EchoArgs: Codable {
            let message: String
        }

        let tool = MCPTool(
            name: "echo",
            description: "Echo a message",
            propertyDescriptions: ["message": "The message to echo"]
        ) { (args: EchoArgs) in
            .text(args.message)
        }

        let def = tool.toDefinition()
        #expect(def.inputSchema.properties?["message"]?.description == "The message to echo")
    }

    @Test("MCPTool explicit schema overrides auto-generation")
    func toolExplicitSchema() {
        struct Args: Codable {
            let value: String
        }

        let explicitSchema = MCPSchema(
            properties: ["value": .string("Custom description")],
            required: ["value"]
        )

        let tool = MCPTool(
            name: "test",
            description: "Test",
            schema: explicitSchema
        ) { (args: Args) in
            .text(args.value)
        }

        let def = tool.toDefinition()
        #expect(def.inputSchema.properties?["value"]?.description == "Custom description")
    }

    @Test("MCPTool auto-generated schema works end-to-end")
    func toolAutoSchemaEndToEnd() async throws {
        struct MathArgs: Codable {
            let a: Double
            let b: Double
        }

        let tool = MCPTool(
            name: "add",
            description: "Add two numbers",
            propertyDescriptions: [
                "a": "First number",
                "b": "Second number"
            ]
        ) { (args: MathArgs) in
            .text("Result: \(args.a + args.b)")
        }

        // Verify schema
        let def = tool.toDefinition()
        #expect(def.inputSchema.properties?["a"]?.type == "number")
        #expect(def.inputSchema.properties?["b"]?.type == "number")
        #expect(def.inputSchema.properties?["a"]?.description == "First number")
        #expect(def.inputSchema.required?.count == 2)

        // Verify handler still works
        let result = try await tool.handler(AnyCodable(["a": 3.0, "b": 4.0] as [String: Any]))
        guard case .text(let text) = result else {
            Issue.record("Expected text result")
            return
        }
        #expect(text == "Result: 7.0")
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
