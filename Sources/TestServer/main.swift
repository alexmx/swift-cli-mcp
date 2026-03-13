import Foundation
import SwiftMCP

// MARK: - Typed Arguments

struct EchoArgs: MCPToolInput {
    @InputProperty("The message to echo")
    var message: String
}

struct ReportArgs: MCPToolInput {
    @InputProperty("Report title")
    var title: String
}

struct DivideArgs: MCPToolInput {
    @InputProperty("First number")
    var a: Double

    @InputProperty("Second number")
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
    ],
    resourceTemplates: [
        MCPResourceTemplate(
            uriTemplate: "file:///{path}",
            name: "Project Files",
            description: "Read any file in the project",
            mimeType: "text/plain"
        )
    ],
    prompts: [
        MCPPrompt(
            name: "code_review",
            description: "Review code for issues and improvements",
            arguments: [
                .init(name: "code", description: "The code to review", required: true),
                .init(name: "language", description: "Programming language")
            ]
        ) { args in
            let code = args["code"] ?? ""
            let lang = args["language"] ?? "unknown"
            return MCPPromptResult(
                description: "Code review prompt for \(lang)",
                messages: [
                    .init(role: .user, content: .text("Please review the following \(lang) code for bugs, style issues, and improvements:\n\n```\(lang)\n\(code)\n```"))
                ]
            )
        },

        MCPPrompt(
            name: "summarize",
            description: "Summarize content with a specific focus",
            arguments: [
                .init(name: "content", description: "The content to summarize", required: true),
                .init(name: "focus", description: "What to focus the summary on")
            ]
        ) { args in
            let content = args["content"] ?? ""
            let focus = args["focus"].map { " Focus on: \($0)." } ?? ""
            return MCPPromptResult(messages: [
                .init(role: .user, content: .text("Summarize the following content.\(focus)\n\n\(content)"))
            ])
        }
    ]
)

// Run the server
await server.run()
