import Foundation
import SwiftCliMcp

// MARK: - Typed Arguments

struct EchoArgs: Codable {
    let message: String
}

struct ReportArgs: Codable {
    let title: String
}

struct DivideArgs: Codable {
    let a: Double
    let b: Double
}

// MARK: - Test Server

let server = MCPServer(
    name: "test-mcp-server",
    version: "1.0.0",
    description: "Test server demonstrating all MCP features",
    tools: [
        // Typed tool - type-safe with automatic validation
        MCPTool(
            name: "echo",
            description: "Echo back the input message (typed)",
            schema: MCPSchema(
                properties: [
                    "message": .string("The message to echo")
                ],
                required: ["message"]
            )
        ) { (args: EchoArgs) in
            return .text("Echo: \(args.message)")
        },

        // Typed tool with multiple content blocks
        MCPTool(
            name: "generate_report",
            description: "Generate a report with text and structured data (typed)",
            schema: MCPSchema(
                properties: [
                    "title": .string("Report title")
                ],
                required: ["title"]
            )
        ) { (args: ReportArgs) in
            return .content([
                .text("# \(args.title)\n\nThis is a test report."),
                .text("Status: All systems operational")
            ])
        },

        // Typed tool with error handling - no manual casting needed!
        MCPTool(
            name: "divide",
            description: "Divide two numbers (typed with validation)",
            schema: MCPSchema(
                properties: [
                    "a": .number("First number"),
                    "b": .number("Second number")
                ],
                required: ["a", "b"]
            )
        ) { (args: DivideArgs) in
            // No casting needed - args.a and args.b are guaranteed to be Double
            guard args.b != 0 else {
                throw NSError(domain: "test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Division by zero"])
            }

            return .text("Result: \(args.a / args.b)")
        },

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
