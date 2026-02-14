import Foundation

/// A reusable MCP server that communicates via JSON-RPC 2.0 over stdio.
///
/// Usage:
/// ```swift
/// let server = MCPServer(name: "my-tool", version: "1.0.0", tools: [
///     MCPTool(name: "greet", description: "Say hello", inputSchema: [...]) { args in
///         return "Hello, \(args["name"] ?? "world")!"
///     }
/// ])
/// await server.run()
/// ```
public struct MCPServer: Sendable {
    let name: String
    let version: String
    let tools: [MCPTool]

    public init(name: String, version: String, tools: [MCPTool]) {
        self.name = name
        self.version = version
        self.tools = tools
    }

    /// Start the stdio loop. Blocks until stdin closes.
    public func run() async {
        log("MCP server '\(name)' v\(version) starting with \(tools.count) tool(s)")

        while let line = readLine(strippingNewline: true) {
            guard !line.isEmpty else { continue }

            guard let data = line.data(using: .utf8),
                  let request = JSONRPCParser.parse(data) else {
                write(JSONRPCResponse.error(id: nil, code: MCPConstants.parseError, message: "Parse error"))
                continue
            }

            // Notifications have no id and expect no response
            if request.isNotification {
                log("Notification: \(request.method)")
                continue
            }

            let response = await handleRequest(request)
            write(response)
        }

        log("stdin closed, shutting down")
    }

    // MARK: - Request Routing

    private func handleRequest(_ request: JSONRPCRequest) async -> Data {
        guard let id = request.id else {
            return JSONRPCResponse.error(id: nil, code: MCPConstants.parseError, message: "Missing id")
        }

        switch request.method {
        case "initialize":
            return handleInitialize(id: id)
        case "tools/list":
            return handleToolsList(id: id)
        case "tools/call":
            return await handleToolsCall(id: id, params: request.params)
        case "ping":
            return JSONRPCResponse.success(id: id, result: [:] as [String: Any])
        default:
            return JSONRPCResponse.error(id: id, code: MCPConstants.methodNotFound, message: "Method not found: \(request.method)")
        }
    }

    // MARK: - Method Handlers

    private func handleInitialize(id: JSONRPCId) -> Data {
        let result: [String: Any] = [
            "protocolVersion": MCPConstants.protocolVersion,
            "capabilities": [
                "tools": [
                    "listChanged": false,
                ] as [String: Any],
            ] as [String: Any],
            "serverInfo": [
                "name": name,
                "version": version,
            ] as [String: Any],
        ]
        return JSONRPCResponse.success(id: id, result: result)
    }

    private func handleToolsList(id: JSONRPCId) -> Data {
        let toolDefs = tools.map { $0.definition() }
        let result: [String: Any] = ["tools": toolDefs]
        return JSONRPCResponse.success(id: id, result: result)
    }

    private func handleToolsCall(id: JSONRPCId, params: [String: Any]) async -> Data {
        guard let toolName = params["name"] as? String else {
            return JSONRPCResponse.error(id: id, code: MCPConstants.invalidParams, message: "Missing tool name")
        }

        guard let tool = tools.first(where: { $0.name == toolName }) else {
            return JSONRPCResponse.error(id: id, code: MCPConstants.invalidParams, message: "Unknown tool: \(toolName)")
        }

        let arguments = params["arguments"] as? [String: Any] ?? [:]

        do {
            let resultText = try await tool.handler(arguments)
            let result: [String: Any] = [
                "content": [
                    ["type": "text", "text": resultText] as [String: Any],
                ],
                "isError": false,
            ]
            return JSONRPCResponse.success(id: id, result: result)
        } catch {
            let result: [String: Any] = [
                "content": [
                    ["type": "text", "text": error.localizedDescription] as [String: Any],
                ],
                "isError": true,
            ]
            return JSONRPCResponse.success(id: id, result: result)
        }
    }

    // MARK: - I/O

    private func write(_ data: Data) {
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }

    private func log(_ message: String) {
        FileHandle.standardError.write(Data("[\(name)] \(message)\n".utf8))
    }
}
