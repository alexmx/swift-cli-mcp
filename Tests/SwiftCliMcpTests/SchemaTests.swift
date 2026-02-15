import Testing
import Foundation
@testable import SwiftCliMcp

@Suite("Schema and Tool")
struct SchemaTests {

    // MARK: - Typed Schema Tests

    @Test("Empty schema")
    func emptySchema() {
        let schema = MCPSchema()
        let dict = schema.toDict()

        #expect(dict["type"] as? String == "object")
        #expect(dict["properties"] == nil)
        #expect(dict["required"] == nil)
    }

    @Test("Schema with properties")
    func schemaWithProperties() {
        let schema = MCPSchema(
            properties: [
                "name": .string("User name"),
                "age": .integer("User age")
            ],
            required: ["name"]
        )
        let dict = schema.toDict()

        #expect(dict["type"] as? String == "object")

        let props = dict["properties"] as? [String: [String: Any]]
        #expect(props?["name"]?["type"] as? String == "string")
        #expect(props?["name"]?["description"] as? String == "User name")
        #expect(props?["age"]?["type"] as? String == "integer")

        let required = dict["required"] as? [String]
        #expect(required == ["name"])
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
        let dict = merged.toDict()

        let props = dict["properties"] as? [String: [String: Any]]
        #expect(props?.keys.count == 2)
        #expect(props?["a"] != nil)
        #expect(props?["b"] != nil)

        let required = dict["required"] as? [String]
        #expect(required?.count == 2)
        #expect(required?.contains("a") == true)
        #expect(required?.contains("b") == true)
    }

    // MARK: - Property Tests

    @Test("String property")
    func stringProperty() {
        let prop = MCPProperty.string("A string field")
        let dict = prop.toDict()

        #expect(dict["type"] as? String == "string")
        #expect(dict["description"] as? String == "A string field")
    }

    @Test("All property types")
    func allPropertyTypes() {
        let types: [(MCPProperty, String)] = [
            (.string("str"), "string"),
            (.integer("int"), "integer"),
            (.boolean("bool"), "boolean"),
            (.number("num"), "number")
        ]

        for (prop, expectedType) in types {
            let dict = prop.toDict()
            #expect(dict["type"] as? String == expectedType)
        }
    }

    // MARK: - Tool Tests

    @Test("Tool with typed schema")
    func toolWithTypedSchema() {
        let tool = MCPTool(
            name: "test",
            description: "Test tool",
            schema: MCPSchema(
                properties: ["input": .string("Input value")],
                required: ["input"]
            )
        ) { _ in .text("result") }

        let def = tool.definition()
        #expect(def["name"] as? String == "test")
        #expect(def["description"] as? String == "Test tool")

        let schema = def["inputSchema"] as? [String: Any]
        #expect(schema?["type"] as? String == "object")

        let props = schema?["properties"] as? [String: [String: Any]]
        #expect(props?["input"]?["type"] as? String == "string")
    }

    @Test("Tool with string schema (legacy)")
    func toolWithStringSchema() {
        let schemaJSON = """
        {
            "properties": {
                "name": {"type": "string", "description": "Name"}
            },
            "required": ["name"],
            "additionalProperties": false
        }
        """

        let tool = MCPTool(
            name: "legacy",
            description: "Legacy tool",
            schema: schemaJSON
        ) { _ in .text("ok") }

        let def = tool.definition()
        let schema = def["inputSchema"] as? [String: Any]

        // Should preserve all fields including additionalProperties
        #expect(schema?["additionalProperties"] as? Bool == false)
        #expect(schema?["type"] as? String == "object")

        let props = schema?["properties"] as? [String: [String: Any]]
        #expect(props?["name"]?["type"] as? String == "string")
    }

    @Test("Tool with invalid string schema")
    func toolWithInvalidStringSchema() {
        let tool = MCPTool(
            name: "invalid",
            description: "Invalid schema",
            schema: "not json"
        ) { _ in .text("ok") }

        let def = tool.definition()
        let schema = def["inputSchema"] as? [String: Any]

        // Should fallback to minimal schema
        #expect(schema?["type"] as? String == "object")
    }

    @Test("Tool handler - string convenience init")
    func toolStringHandler() async throws {
        let tool = MCPTool(
            name: "echo",
            description: "Echo",
            stringHandler: { args in
                return args["msg"] as? String ?? "empty"
            }
        )

        let result = try await tool.handler(["msg": "hello"])
        guard case .text(let text) = result else {
            Issue.record("Expected text result")
            return
        }
        #expect(text == "hello")
    }
}
