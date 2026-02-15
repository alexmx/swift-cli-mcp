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

**MCPServer.swift** - Main server handling JSON-RPC over stdio
- Routes requests to method handlers (initialize, tools/list, tools/call, resources/list, resources/read)
- Graceful shutdown via SIGTERM/SIGINT

**MCPTool.swift** - Type-safe tool and resource definitions
- `MCPTool<Arguments: Codable>` - Tools with typed argument validation
- `MCPResource` - File/data exposure
- `MCPSchema` and `MCPProperty` - Schema builders
- `MCPContent` and `MCPToolResult` - Return types

**MCPTypes.swift** - JSON-RPC types (all Codable-based)
- Request/response types, error codes, protocol constants

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

**New Tool Type**: Add case to `MCPContent` enum, update `toDict()`

**New JSON-RPC Method**: Add case to switch in `handleRequest()`, create handler

**New Schema Property Type**: Add static method to `MCPProperty`

**New Tests**: Add to appropriate suite in Tests/SwiftCliMcpTests/

## Requirements

- Swift 6.0+ (swift-tools-version: 6.2)
- macOS 15.0+
- Dependencies: `swift-atomics`
- Run `swiftformat .` before committing
