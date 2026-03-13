# Swift CLI MCP

A lightweight Swift library for building stdio-based [Model Context Protocol (MCP)](https://modelcontextprotocol.io) servers.

## Features

- **Type-safe tools** with Codable argument validation, auto-generated schemas, and `@InputProperty` annotations
- **Resources** for exposing files and data, with URI template support
- **Prompts** for reusable prompt templates with typed arguments
- **Logging** with client-controlled log levels (`logging/setLevel`)
- **Concurrent request handling** with back-pressure and request cancellation
- **Graceful shutdown** on SIGTERM/SIGINT
- Full JSON-RPC 2.0 compliance

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/alexmx/swift-cli-mcp.git", from: "1.0.0")
]
```

## Quick Start

```swift
import SwiftMCP

struct EchoArgs: MCPToolInput {
    @InputProperty("The message to echo")
    var message: String
}

let server = MCPServer(
    name: "my-tools",
    version: "1.0.0",
    tools: [
        .tool(name: "echo", description: "Echo a message") { (args: EchoArgs) in
            .text("Echo: \(args.message)")
        }
    ],
    resources: [
        .textResource(uri: "config://version", name: "Version", mimeType: "text/plain") { _ in
            "1.0.0"
        }
    ],
    prompts: [
        .prompt(name: "greet", description: "Generate a greeting", arguments: [
            .required(name: "name", description: "Name to greet")
        ]) { args in
            .userMessage("Say hello to \(args["name"]!)")
        }
    ]
)

await server.run()
```

The schema is auto-generated from `EchoArgs` — property types, required fields, and descriptions are all inferred from the struct definition.

## Tools

### Typed Arguments with `@InputProperty`

Use `@InputProperty` to co-locate descriptions with your properties. The schema is auto-generated — property types are inferred (`String` → `"string"`, `Int` → `"integer"`, `Bool` → `"boolean"`, `Double` → `"number"`) and non-optional properties are marked as required:

```swift
struct ListFilesArgs: MCPToolInput {
    @InputProperty("Directory path")
    var path: String

    @InputProperty("Include subdirectories")
    var recursive: Bool?
}

.tool(name: "list_files", description: "List files in a directory") { (args: ListFilesArgs) in
    let files = try FileManager.default.contentsOfDirectory(atPath: args.path)
    return .text(files.joined(separator: "\n"))
}
```

### Simple Tools

For tools without arguments or with a single string argument:

```swift
// No arguments
.tool(name: "ping", description: "Check server status") {
    .text("pong")
}

// Single string argument
.tool(name: "echo", description: "Echo a message", argumentName: "message", argumentDescription: "The message to echo") { message in
    .text("Echo: \(message)")
}
```

### Manual Schemas

Override auto-generation for full control:

```swift
.tool(
    name: "list_files",
    description: "List files in a directory",
    schema: MCPSchema(
        properties: [
            "path": .string("Directory path"),
            "recursive": .boolean("Include subdirectories")
        ],
        required: ["path"]
    )
) { (args: ListFilesArgs) in
    let files = try FileManager.default.contentsOfDirectory(atPath: args.path)
    return .text(files.joined(separator: "\n"))
}
```

### Multiple Content Blocks

Return multiple content items in a single response:

```swift
.tool(name: "report", description: "Generate report") { (args: ReportArgs) in
    .content([
        .text("# Report\n\nGenerated at \(Date())"),
        .text("Status: Complete"),
        .image(data: chartData, mimeType: "image/png")
    ])
}
```

### Error Handling

Errors are automatically caught and returned to the client:

```swift
.tool(name: "divide", description: "Divide two numbers") { (args: DivideArgs) in
    guard args.b != 0 else {
        throw NSError(domain: "math", code: 1, userInfo: [NSLocalizedDescriptionKey: "Division by zero"])
    }
    return .text("Result: \(args.a / args.b)")
}
```

Type mismatches and missing required fields are validated automatically.

## Resources

Expose files, logs, or dynamic data:

```swift
// Text resource — handler returns String, URI plumbed automatically
.textResource(uri: "file:///logs/app.log", name: "Application Log", mimeType: "text/plain") { _ in
    try String(contentsOfFile: "/var/log/app.log")
}

// Binary resource — handler returns Data, URI plumbed automatically
.blobResource(uri: "img://logo", name: "Logo", mimeType: "image/png") { _ in
    try Data(contentsOf: URL(fileURLWithPath: "/assets/logo.png"))
}

// Full handler when you need custom MCPResourceContents
.resource(uri: "system://stats", name: "System Stats", mimeType: "application/json") {
    let stats = """
    {"cpu": \(ProcessInfo.processInfo.processorCount)}
    """
    return .text(uri: "system://stats", stats, mimeType: "application/json")
}
```

### Resource Templates

Advertise URI patterns (RFC 6570) that clients can fill in:

```swift
resourceTemplates: [
    .template(uriTemplate: "file:///{path}", name: "Project Files", mimeType: "text/plain"),
    .template(uriTemplate: "db:///{table}/{id}", name: "Database Records")
]
```

## Prompts

Define reusable prompt templates with typed arguments:

```swift
.prompt(
    name: "code_review",
    description: "Review code for issues",
    arguments: [
        .required(name: "code", description: "The code to review"),
        .optional(name: "language", description: "Programming language")
    ]
) { args in
    let code = args["code"] ?? ""
    let lang = args["language"] ?? "unknown"
    return .userMessage(
        "Review this \(lang) code for bugs and improvements:\n\n```\(lang)\n\(code)\n```",
        description: "Code review prompt"
    )
}
```

### Multi-message Prompts

```swift
.prompt(name: "interview", description: "Technical interview") { _ in
    .result(messages: [
        .user("Ask me a technical question about Swift concurrency."),
        .assistant("I'll ask you about structured concurrency and actors.")
    ])
}
```

## Logging

### Sending Logs to the Client

```swift
await server.sendLog(level: .info, message: "Processing started")
await server.sendLog(level: .warning, message: "Resource usage high", logger: "monitor")
```

The client can control the minimum log level via `logging/setLevel`. Messages below the minimum are filtered automatically.

Available levels (by severity): `debug`, `info`, `notice`, `warning`, `error`, `critical`, `alert`, `emergency`

### Custom Server Logging

Control where internal server logs go:

```swift
let server = MCPServer(
    name: "my-server",
    version: "1.0.0",
    tools: [...],
    logHandler: { message in
        print("[\(Date())] \(message)")
    }
)
```

## Concurrency

Requests are dispatched concurrently so slow tool handlers don't block others. The server applies back-pressure with a max concurrency limit (16) and supports request cancellation via `notifications/cancelled`.

## Schemas

Define schemas with typed properties:

```swift
MCPSchema(
    properties: [
        "name": .string("User's name"),
        "age": .integer("User's age"),
        "active": .boolean("Account status"),
        "score": .number("Performance score")
    ],
    required: ["name"]
)
```

Merge schemas for reusable properties:

```swift
let base = MCPSchema(properties: ["apiKey": .string("API key")], required: ["apiKey"])
let extended = base.merging(MCPSchema(properties: ["timeout": .integer("Timeout")]))
```

## Supported MCP Methods

| Method | Description |
|--------|-------------|
| `initialize` | Server info and capabilities |
| `ping` | Health check |
| `tools/list` | List available tools |
| `tools/call` | Execute a tool |
| `resources/list` | List available resources |
| `resources/read` | Read a resource |
| `resources/templates/list` | List URI templates |
| `prompts/list` | List available prompts |
| `prompts/get` | Get a rendered prompt |
| `logging/setLevel` | Set minimum log level |
| `notifications/cancelled` | Cancel an in-flight request |

## Requirements

- Swift 6.0+
- macOS 15.0+

## Resources

- [MCP Specification](https://modelcontextprotocol.io)

## License

MIT License - see [LICENSE](LICENSE) file for details.
