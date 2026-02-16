# Swift CLI MCP

Swift library for building Model Context Protocol (MCP) servers for CLI tools. Provides type-safe, Codable-based API for defining tools, resources, and logging over JSON-RPC 2.0 via stdio.

## Development Commands

```bash
# Build the library
swift build

# Run tests (39 tests across 5 suites)
swift test

# Build and run example server
swift run test-server

# Format code (required before commits)
swiftformat .

# Test the server interactively
./scripts/test_mcp.sh
```

## Architecture

The codebase is organized into feature-based modules for clear separation of concerns:

**Core/** - Server implementation
- `MCPServer.swift` - Server initialization, run loop, signal handling, logging, I/O
- `MCPServerHandlers.swift` - Request routing and method handlers (extension)

**Tools/** - Tool definitions and schemas
- `MCPTool.swift` - Type-safe tool definition with `MCPTool<Arguments: Codable>`
- `MCPSchema.swift` - JSON Schema builders (`MCPSchema` and `MCPProperty`)

**Resources/** - Resource definitions
- `MCPResource.swift` - Resource exposure and contents handling

**Content/** - Shared content types
- `MCPContent.swift` - Content types (`MCPContent`) and tool results (`MCPToolResult`)

**Protocol/** - JSON-RPC implementation
- `JSONRPC.swift` - JSON-RPC 2.0 types, parsing, response building, AnyCodable
- `MCPConstants.swift` - Protocol version and error codes

## Key Patterns

**Type-Safe Tools** - All tools use `MCPTool<Arguments: Codable>`
```swift
struct MyArgs: Codable { let name: String }
MCPTool(...) { (args: MyArgs) in .text(args.name) }
```

**Error Handling** - Errors auto-caught and returned to client. No crashes.

**Sendable Compliance** - Swift 6 strict concurrency throughout.

## Important Constraints

**Tools API**
- Only one way to create tools: `MCPTool<Arguments: Codable>`
- Schema is always `MCPSchema` (no string-based schemas)
- Handler must return `MCPToolResult` (.text or .content)

**Server Communication**
- Stdio only - reads from stdin, writes to stdout
- Logs to stderr (or custom handler)
- JSON-RPC 2.0 with version validation ("2.0" required)

**Testing**
- Uses modern Swift Testing (`@Test`, `#expect`)
- No XCTest - do not use XCTAssert* methods
- Test structs use `@Suite` for organization

## Adding New Features

**New Content Type**: Add case to `MCPContent` enum in `Content/MCPContent.swift`, update `toDict()`

**New JSON-RPC Method**: Add case in `Core/MCPServerHandlers.swift` `handleRequest()`, create handler method

**New Schema Property Type**: Add static method to `MCPProperty` in `Tools/MCPSchema.swift`

**New Protocol Feature**: Update appropriate file in `Protocol/` (JSONRPC types or constants)

**New Tests**: Add to appropriate suite in `Tests/SwiftCliMcpTests/`

## Requirements

- Swift 6.0+ (swift-tools-version: 6.2)
- macOS 15.0+
- Dependencies: `swift-atomics`
- Run `swiftformat .` before committing
