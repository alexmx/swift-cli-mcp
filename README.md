# SwiftCliMcp

A production-ready, type-safe Swift library for building [Model Context Protocol (MCP)](https://modelcontextprotocol.io) servers for CLI tools.

## Features

✅ **Full MCP Protocol Support**
- Tools (execute commands, run scripts)
- Resources (expose files, logs, data)
- Logging (server-to-client notifications)
- JSON-RPC 2.0 compliant

✅ **Production Ready**
- Graceful shutdown (SIGTERM/SIGINT)
- Non-blocking async I/O
- Comprehensive error handling
- Type-safe with Swift 6 Sendable compliance

✅ **High Performance**
- O(1) tool/resource lookup
- Efficient Codable-based JSON parsing
- Lock-free atomic operations

✅ **Developer Friendly**
- Modern Swift Testing (38+ tests)
- Typed schemas with validation
- Configurable logging
- Backward compatible APIs

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/alexmx/swift-cli-mcp.git", from: "1.0.0")
]
```

## Quick Start

```swift
import SwiftCliMcp

// Define typed arguments
struct EchoArgs: Codable {
    let message: String
}

let server = MCPServer(
    name: "my-cli-tools",
    version: "1.0.0",
    description: "My awesome CLI tools",
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

## Usage

### Tools

All tools use strongly-typed Codable structs for automatic validation and type safety:

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
            "recursive": .boolean("Recursive listing")
        ],
        required: ["path"]
    )
) { (args: ListFilesArgs) in
    // ✅ No casting needed - args.path is guaranteed to be String
    // ✅ Type mismatches caught automatically
    let files = try FileManager.default.contentsOfDirectory(atPath: args.path)
    return .text(files.joined(separator: "\n"))
}
```

**Benefits:**
- ✅ Compile-time type safety
- ✅ No manual casting
- ✅ Automatic validation via Codable
- ✅ Clear error messages for type mismatches
- ✅ Support for nested structures, optionals, arrays

#### Multiple Content Blocks

```swift
MCPTool(name: "report", description: "Generate report") { args in
    return .content([
        .text("# Report\n\nGenerated at \(Date())"),
        .text("Status: Complete"),
        .image(data: chartImageData, mimeType: "image/png")
    ])
}
```

#### Complex Typed Arguments

Full Codable support including nested structures:

```swift
struct Address: Codable {
    let street: String
    let city: String
    let zip: String?
}

struct RegisterUserArgs: Codable {
    let name: String
    let email: String
    let address: Address
    let tags: [String]?
}

MCPTool(name: "register", description: "Register user") { (args: RegisterUserArgs) in
    return .text("Registered \(args.name) in \(args.address.city)")
}
```


### Resources

Resources expose files, logs, or dynamic data:

```swift
MCPResource(
    uri: "file:///logs/app.log",
    name: "Application Log",
    description: "Current application log file",
    mimeType: "text/plain"
) {
    let logContent = try String(contentsOfFile: "/var/log/app.log")
    return MCPResourceContents(uri: "file:///logs/app.log", text: logContent)
}
```

#### Dynamic Resources

```swift
MCPResource(
    uri: "system://stats",
    name: "System Stats",
    mimeType: "application/json"
) {
    let stats = [
        "cpu": ProcessInfo.processInfo.processorCount,
        "memory": ProcessInfo.processInfo.physicalMemory
    ]
    let json = try JSONEncoder().encode(stats)
    return MCPResourceContents(
        uri: "system://stats",
        blob: json,
        mimeType: "application/json"
    )
}
```

### Logging

Send log messages to the client:

```swift
let server = MCPServer(name: "my-server", version: "1.0", tools: [...])

// In your tool handlers or elsewhere
server.sendLog(level: .info, message: "Processing started", logger: "worker")
server.sendLog(level: .warning, message: "Resource usage high")
server.sendLog(level: .error, message: "Failed to connect to database")
```

#### Log Levels
- `debug`, `info`, `notice`, `warning`, `error`, `critical`, `alert`, `emergency`

### Custom Logging

Control where logs go:

```swift
// Log to file
let server = MCPServer(
    name: "my-server",
    version: "1.0",
    tools: [...],
    logHandler: { message in
        let log = "[\(Date())] \(message)\n"
        try? log.write(toFile: "/var/log/mcp.log", atomically: true, encoding: .utf8)
    }
)

// Use os_log
import os
let logger = Logger(subsystem: "com.example.mcp", category: "server")
let server = MCPServer(
    name: "my-server",
    version: "1.0",
    tools: [...],
    logHandler: { logger.info("\($0)") }
)

// Disable logging
let server = MCPServer(
    name: "my-server",
    version: "1.0",
    tools: [...],
    logHandler: { _ in }
)
```

### Schemas

```swift
let schema = MCPSchema(
    properties: [
        "name": .string("User's name"),
        "age": .integer("User's age"),
        "active": .boolean("Account status"),
        "score": .number("Performance score")
    ],
    required: ["name", "age"]
)
```

#### Schema Merging

```swift
let baseSchema = MCPSchema(
    properties: ["apiKey": .string("API key")],
    required: ["apiKey"]
)

let extendedSchema = baseSchema.merging(MCPSchema(
    properties: ["timeout": .integer("Timeout in seconds")],
    required: []
))
```


## Advanced Features

### Graceful Shutdown

The server handles SIGTERM and SIGINT automatically:

```bash
# Server stops gracefully on Ctrl+C
./my-mcp-server
^C
[my-server] Shutting down gracefully
[my-server] stdin closed, shutting down
```

### Error Handling

#### Typed Arguments - Automatic Validation

With typed arguments, validation errors are caught automatically:

```swift
struct DivideArgs: Codable {
    let a: Double
    let b: Double
}

MCPTool(name: "divide", description: "Divide numbers") { (args: DivideArgs) in
    // ✅ Type validation already done - a and b are guaranteed to be Double
    // ✅ Missing fields automatically error
    // ✅ Wrong types (e.g., string instead of number) automatically error

    guard args.b != 0 else {
        throw NSError(domain: "math", code: 2,
                     userInfo: [NSLocalizedDescriptionKey: "Division by zero"])
    }

    return .text("Result: \(args.a / args.b)")
}
```

**Automatic error messages:**
- Missing required field: `"The data couldn't be read because it is missing."`
- Wrong type: `"Expected to decode Double but found a string instead."`
- Invalid JSON: `"The data couldn't be read because it isn't in the correct format."`

### Server Introspection

```swift
let server = MCPServer(name: "my-server", version: "1.0", tools: [...])

print("Server: \(server.name) v\(server.version)")
print("Tools: \(server.tools.map { $0.name }.joined(separator: ", "))")
print("Resources: \(server.resources.count)")
```

## Testing

Run the comprehensive test suite:

```bash
swift test
```

Run the example test server:

```bash
swift run test-server
```

Test with the included script:

```bash
./test_mcp.sh
```

## Requirements

- Swift 6.0+
- macOS 15.0+
- Dependencies:
  - [swift-atomics](https://github.com/apple/swift-atomics) 1.3.0+

## Architecture

### Type Safety

All JSON-RPC communication uses `Codable` types:
- `JSONRPCRequest` - Incoming requests
- `JSONRPCSuccessResponse` - Successful responses
- `JSONRPCErrorResponse` - Error responses
- `AnyCodable` - Type-erased wrapper for dynamic JSON

### Performance

- **O(1) lookups**: Tools and resources use dictionary-based lookups
- **Async I/O**: Non-blocking `FileHandle.bytes.lines`
- **Lock-free**: Atomic operations for shutdown flag

### Concurrency

Full Swift 6 strict concurrency compliance:
- All public types are `Sendable`
- Thread-safe shutdown handling
- No data races

## Examples

See the [test server](Sources/TestServer/main.swift) for a complete example demonstrating:
- Multiple tools with different return types
- Static and dynamic resources
- Error handling
- Schema validation

## Contributing

Contributions welcome! Please ensure:
- All tests pass (`swift test`)
- Code follows Swift conventions
- New features include tests

## License

[Add your license here]

## Resources

- [MCP Specification](https://modelcontextprotocol.io)
- [JSON-RPC 2.0 Specification](https://www.jsonrpc.org/specification)
- [Swift Package Manager](https://swift.org/package-manager/)
