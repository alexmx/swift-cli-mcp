import Foundation
import SwiftCliMcp

// MARK: - Test Server

let server = MCPServer(
    name: "test-mcp-server",
    version: "1.0.0",
    description: "Test server demonstrating all MCP features",
    tools: [
        // Simple text tool
        MCPTool(
            name: "echo",
            description: "Echo back the input message",
            schema: MCPSchema(
                properties: [
                    "message": .string("The message to echo")
                ],
                required: ["message"]
            )
        ) { args in
            let message = args["message"] as? String ?? ""
            return .text("Echo: \(message)")
        },

        // Tool that returns multiple content blocks
        MCPTool(
            name: "generate_report",
            description: "Generate a report with text and structured data",
            schema: MCPSchema(
                properties: [
                    "title": .string("Report title")
                ],
                required: ["title"]
            )
        ) { args in
            let title = args["title"] as? String ?? "Untitled"
            return .content([
                .text("# \(title)\n\nThis is a test report."),
                .text("Status: All systems operational")
            ])
        },

        // Tool with error handling
        MCPTool(
            name: "divide",
            description: "Divide two numbers",
            schema: MCPSchema(
                properties: [
                    "a": .number("First number"),
                    "b": .number("Second number")
                ],
                required: ["a", "b"]
            )
        ) { args in
            guard let a = args["a"] as? Double,
                  let b = args["b"] as? Double else {
                throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid numbers"])
            }

            guard b != 0 else {
                throw NSError(domain: "test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Division by zero"])
            }

            return .text("Result: \(a / b)")
        },

        // Tool that uses logging
        MCPTool(
            name: "slow_task",
            description: "Simulates a slow task with progress logging",
            schema: MCPSchema()
        ) { args in
            // Note: This won't work as expected since we can't access server here
            // In real usage, tools would need server reference or use a global/actor
            try await Task.sleep(for: .milliseconds(100))
            return .text("Task completed")
        }
    ],
    resources: [
        // Static text resource
        MCPResource(
            uri: "test://readme",
            name: "README",
            description: "Project README file",
            mimeType: "text/plain"
        ) {
            let content = """
            # Test MCP Server

            This is a test server demonstrating all MCP features:
            - Tools (echo, generate_report, divide, slow_task)
            - Resources (this README, system info)
            - Logging capabilities
            - Graceful shutdown (Ctrl+C)
            """
            return MCPResourceContents(uri: "test://readme", text: content)
        },

        // Dynamic resource
        MCPResource(
            uri: "test://sysinfo",
            name: "System Info",
            description: "Current system information",
            mimeType: "application/json"
        ) {
            let info = """
            {
                "timestamp": "\(Date())",
                "platform": "macOS",
                "server": "test-mcp-server"
            }
            """
            return MCPResourceContents(uri: "test://sysinfo", text: info, mimeType: "application/json")
        }
    ]
)

// Run the server
await server.run()
