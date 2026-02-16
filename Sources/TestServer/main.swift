import Foundation
import SwiftMCP

// MARK: - Typed Arguments

struct EchoArgs: MCPToolInput {
    @PropertyDescription("The message to echo")
    var message: String
}

struct ReportArgs: MCPToolInput {
    @PropertyDescription("Report title")
    var title: String
}

struct DivideArgs: MCPToolInput {
    @PropertyDescription("First number")
    var a: Double

    @PropertyDescription("Second number")
    var b: Double
}

// MARK: - Test Server

let server = MCPServer(
    name: "test-mcp-server",
    version: "1.0.0",
    description: "Test server demonstrating all MCP features",
    tools: [
        MCPTool(
            name: "echo",
            description: "Echo back the input message"
        ) { (args: EchoArgs) in
            return .text("Echo: \(args.message)")
        },

        MCPTool(
            name: "generate_report",
            description: "Generate a report with text and structured data"
        ) { (args: ReportArgs) in
            return .content([
                .text("# \(args.title)\n\nThis is a test report."),
                .text("Status: All systems operational")
            ])
        },

        MCPTool(
            name: "divide",
            description: "Divide two numbers"
        ) { (args: DivideArgs) in
            guard args.b != 0 else {
                throw NSError(
                    domain: "test",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Division by zero"]
                )
            }

            return .text("Result: \(args.a / args.b)")
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
