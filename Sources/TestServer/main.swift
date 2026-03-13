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
        .tool(name: "echo", description: "Echo back the input message") { (args: EchoArgs) in
            .text("Echo: \(args.message)")
        },

        .tool(name: "generate_report", description: "Generate a report with text and structured data") { (args: ReportArgs) in
            .content([
                .text("# \(args.title)\n\nThis is a test report."),
                .text("Status: All systems operational")
            ])
        },

        .tool(name: "divide", description: "Divide two numbers") { (args: DivideArgs) in
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
        .textResource(uri: "test://readme", name: "README", description: "Project README file", mimeType: "text/plain") { _ in
            """
            # Test MCP Server

            This is a test server demonstrating all MCP features:
            - Tools (echo, generate_report, divide)
            - Resources (this README, system info)
            - Prompts (code_review, summarize)
            - Logging capabilities
            - Graceful shutdown (Ctrl+C)
            """
        },

        .textResource(uri: "test://sysinfo", name: "System Info", description: "Current system information", mimeType: "application/json") { _ in
            """
            {
                "timestamp": "\(Date())",
                "platform": "macOS",
                "server": "test-mcp-server"
            }
            """
        }
    ],
    resourceTemplates: [
        .template(uriTemplate: "file:///{path}", name: "Project Files", description: "Read any file in the project", mimeType: "text/plain")
    ],
    prompts: [
        .prompt(
            name: "code_review",
            description: "Review code for issues and improvements",
            arguments: [
                .required(name: "code", description: "The code to review"),
                .optional(name: "language", description: "Programming language")
            ]
        ) { args in
            let code = args["code"] ?? ""
            let lang = args["language"] ?? "unknown"
            return .userMessage(
                "Please review the following \(lang) code for bugs, style issues, and improvements:\n\n```\(lang)\n\(code)\n```",
                description: "Code review prompt for \(lang)"
            )
        },

        .prompt(
            name: "summarize",
            description: "Summarize content with a specific focus",
            arguments: [
                .required(name: "content", description: "The content to summarize"),
                .optional(name: "focus", description: "What to focus the summary on")
            ]
        ) { args in
            let content = args["content"] ?? ""
            let focus = args["focus"].map { " Focus on: \($0)." } ?? ""
            return .userMessage("Summarize the following content.\(focus)\n\n\(content)")
        }
    ]
)

// Run the server
await server.run()
