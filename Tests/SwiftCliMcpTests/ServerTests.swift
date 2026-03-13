import Foundation
@testable import SwiftMCP
import Testing

@Suite("MCP Server")
struct ServerTests {
    @Test("Server initialization")
    func serverInit() {
        struct EmptyArgs: Codable {}

        let server = MCPServer(
            name: "test-server",
            version: "1.0.0",
            description: "Test",
            tools: [
                .tool(name: "tool1", description: "Tool 1") { (_: EmptyArgs) in .text("ok") }
            ],
            resources: [
                .textResource(uri: "test://r1", name: "R1") { _ in "data" }
            ]
        )

        #expect(server.name == "test-server")
        #expect(server.version == "1.0.0")
        #expect(server.description == "Test")
        #expect(server.tools.count == 1)
        #expect(server.resources.count == 1)
    }

    @Test("Server with empty collections")
    func serverEmpty() {
        let server = MCPServer(
            name: "minimal",
            version: "1.0.0"
        )

        #expect(server.tools.isEmpty)
        #expect(server.resources.isEmpty)
        #expect(server.description == nil)
    }

    @Test("Tool lookup by name")
    func toolLookup() {
        struct EmptyArgs: Codable {}

        let server = MCPServer(
            name: "server",
            version: "1.0",
            tools: [
                .tool(name: "echo", description: "Echo") { (_: EmptyArgs) in .text("ok") },
                .tool(name: "test", description: "Test") { (_: EmptyArgs) in .text("ok") }
            ]
        )

        #expect(server.tools.count == 2)
        #expect(server.tools[0].name == "echo")
        #expect(server.tools[1].name == "test")
    }

    @Test("Resource lookup by URI")
    func resourceLookup() {
        let server = MCPServer(
            name: "server",
            version: "1.0",
            resources: [
                .textResource(uri: "file:///a", name: "A") { _ in "a" },
                .textResource(uri: "file:///b", name: "B") { _ in "b" }
            ]
        )

        #expect(server.resources.count == 2)
        #expect(server.resources[0].uri == "file:///a")
        #expect(server.resources[1].uri == "file:///b")
    }

    @Test("Log levels")
    func logLevels() {
        // Verify all log levels are defined
        let levels: [MCPServer.LogLevel] = [
            .debug, .info, .notice, .warning,
            .error, .critical, .alert, .emergency
        ]

        for level in levels {
            #expect(level.rawValue.isEmpty == false)
        }
    }

    @Test("Custom log handler")
    func customLogHandler() {
        let server = MCPServer(
            name: "test",
            version: "1.0",
            logHandler: { _ in }
        )

        #expect(server.name == "test")
    }

    @Test("Default log handler")
    func defaultLogHandler() {
        let server = MCPServer(
            name: "default",
            version: "1.0"
        )

        #expect(server.name == "default")
    }

    @Test("Disable logging")
    func disableLogging() {
        let server = MCPServer(
            name: "silent",
            version: "1.0",
            logHandler: { _ in }
        )

        #expect(server.name == "silent")
    }
}
