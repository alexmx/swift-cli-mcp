# Swift CLI MCP

A lightweight Swift library for building stdio-based [Model Context Protocol (MCP)](https://modelcontextprotocol.io) servers.

## Features

- **Type-safe tools** with Codable argument validation
- **Resources** for exposing files and data
- **Logging** to send messages to clients
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

struct EchoArgs: Codable {
    let message: String
}

let server = MCPServer(
    name: "my-tools",
    version: "1.0.0",
    tools: [
        MCPTool(
            name: "echo",
            description: "Echo a message",
            schema: MCPSchema(
                properties: ["message": .string("The message to echo")],
                required: ["message"]
            )
        ) { (args: EchoArgs) in
            return .text("Echo: \(args.message)")
        }
    ]
)

await server.run()
```

## Simple Tools

For tools without arguments or with a single string argument, use the convenience initializers:

### No Arguments

```swift
MCPTool(name: "ping", description: "Check server status") {
    return .text("pong")
}
```

### Single String Argument

```swift
MCPTool(
    name: "echo",
    description: "Echo a message",
    argumentName: "message",
    argumentDescription: "The message to echo"
) { message in
    return .text("Echo: \(message)")
}
```

For tools with multiple arguments or complex types, use the full syntax with Codable structs (see below).

## Usage

### Tools

Define your arguments as a Codable struct:

```swift
struct ListFilesArgs: Codable {
    let path: String
    let recursive: Bool?
}

MCPTool(
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

#### Multiple Content Blocks

Return multiple content items in a single response:

```swift
MCPTool(name: "report", description: "Generate report") { (args: ReportArgs) in
    return .content([
        .text("# Report\n\nGenerated at \(Date())"),
        .text("Status: Complete"),
        .image(data: chartData, mimeType: "image/png")
    ])
}
```

#### Nested Structures

Full Codable support including nested objects and arrays:

```swift
struct Address: Codable {
    let street: String
    let city: String
}

struct UserArgs: Codable {
    let name: String
    let email: String
    let address: Address
    let tags: [String]?
}

MCPTool(name: "register", description: "Register user") { (args: UserArgs) in
    return .text("Registered \(args.name) in \(args.address.city)")
}
```

### Resources

Expose files, logs, or dynamic data:

```swift
MCPResource(
    uri: "file:///logs/app.log",
    name: "Application Log",
    description: "Current application log",
    mimeType: "text/plain"
) {
    let content = try String(contentsOfFile: "/var/log/app.log")
    return MCPResourceContents(uri: "file:///logs/app.log", text: content)
}
```

#### Dynamic Resources

```swift
MCPResource(
    uri: "system://stats",
    name: "System Stats",
    mimeType: "application/json"
) {
    let stats = """
    {
        "cpu": \(ProcessInfo.processInfo.processorCount),
        "memory": \(ProcessInfo.processInfo.physicalMemory)
    }
    """
    return MCPResourceContents(uri: "system://stats", text: stats)
}
```

### Logging

Send log messages to the client:

```swift
server.sendLog(level: .info, message: "Processing started")
server.sendLog(level: .warning, message: "Resource usage high")
server.sendLog(level: .error, message: "Connection failed")
```

Available log levels: `debug`, `info`, `notice`, `warning`, `error`, `critical`, `alert`, `emergency`

#### Custom Logging

Control where server logs go:

```swift
let server = MCPServer(
    name: "my-server",
    version: "1.0.0",
    tools: [...],
    logHandler: { message in
        // Custom logging - write to file, use os_log, etc.
        print("[\(Date())] \(message)")
    }
)
```

### Schemas

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
let baseSchema = MCPSchema(
    properties: ["apiKey": .string("API key")],
    required: ["apiKey"]
)

let extendedSchema = baseSchema.merging(
    MCPSchema(
        properties: ["timeout": .integer("Request timeout")],
        required: []
    )
)
```

### Error Handling

Errors are automatically caught and returned to the client:

```swift
struct DivideArgs: Codable {
    let a: Double
    let b: Double
}

MCPTool(name: "divide", description: "Divide two numbers") { (args: DivideArgs) in
    guard args.b != 0 else {
        throw NSError(
            domain: "math",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Division by zero"]
        )
    }
    return .text("Result: \(args.a / args.b)")
}
```

Type mismatches and missing required fields are validated automatically.

## Resources

- [MCP Specification](https://modelcontextprotocol.io)

## License

MIT License - see [LICENSE](LICENSE) file for details.
