import Foundation
import SwiftMCP

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
        // Schema auto-generated from EchoArgs
        MCPTool(
            name: "echo",
            description: "Echo back the input message",
            propertyDescriptions: ["message": "The message to echo"]
        ) { (args: EchoArgs) in
            return .text("Echo: \(args.message)")
        },

        // Schema auto-generated from ReportArgs
        MCPTool(
            name: "generate_report",
            description: "Generate a report with text and structured data",
            propertyDescriptions: ["title": "Report title"]
        ) { (args: ReportArgs) in
            return .content([
                .text("# \(args.title)\n\nThis is a test report."),
                .text("Status: All systems operational")
            ])
        },

        // Schema auto-generated from DivideArgs
        MCPTool(
            name: "divide",
            description: "Divide two numbers",
            propertyDescriptions: [
                "a": "First number",
                "b": "Second number"
            ]
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
