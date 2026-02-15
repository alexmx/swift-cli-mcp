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
                MCPTool(name: "tool1", description: "Tool 1") { (_: EmptyArgs) in .text("ok") }
            ],
            resources: [
                MCPResource(uri: "test://r1", name: "R1") {
                    MCPResourceContents(uri: "test://r1", text: "data")
                }
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

        let tool1 = MCPTool(name: "echo", description: "Echo") { (_: EmptyArgs) in .text("ok") }
        let tool2 = MCPTool(name: "test", description: "Test") { (_: EmptyArgs) in .text("ok") }

        let server = MCPServer(
            name: "server",
            version: "1.0",
            tools: [tool1, tool2]
        )

        #expect(server.tools.count == 2)
        #expect(server.tools[0].name == "echo")
        #expect(server.tools[1].name == "test")
    }

    @Test("Resource lookup by URI")
    func resourceLookup() {
        let r1 = MCPResource(uri: "file:///a", name: "A") {
            MCPResourceContents(uri: "file:///a", text: "a")
        }
        let r2 = MCPResource(uri: "file:///b", name: "B") {
            MCPResourceContents(uri: "file:///b", text: "b")
        }

        let server = MCPServer(
            name: "server",
            version: "1.0",
            resources: [r1, r2]
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
        // Test that custom handler is accepted
        let server = MCPServer(
            name: "test",
            version: "1.0",
            logHandler: { message in
                // Custom handler could write to file, use os_log, etc.
                // For testing, we just verify it compiles and doesn't crash
                _ = message
            }
        )

        #expect(server.name == "test")
    }

    @Test("Default log handler")
    func defaultLogHandler() {
        // Server without custom handler should use default stderr logging
        let server = MCPServer(
            name: "default",
            version: "1.0"
        )

        #expect(server.name == "default")
        // Default handler logs to stderr - no way to test without capturing stderr
    }

    @Test("Disable logging")
    func disableLogging() {
        // Empty handler effectively disables logging
        let server = MCPServer(
            name: "silent",
            version: "1.0",
            logHandler: { _ in }
        )

        #expect(server.name == "silent")
        // Logs would be suppressed
    }
}
