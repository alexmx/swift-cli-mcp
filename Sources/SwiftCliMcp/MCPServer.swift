import Foundation
import Atomics

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
    public let name: String
    public let version: String
    public let description: String?
    public let tools: [MCPTool]
    public let resources: [MCPResource]
    private let toolsByName: [String: MCPTool]
    private let resourcesByUri: [String: MCPResource]
    private let logHandler: (@Sendable (String) -> Void)?

    // Atomic shutdown flag for signal handling
    private static let shouldShutdown = ManagedAtomic<Bool>(false)

    public init(
        name: String,
        version: String,
        description: String? = nil,
        tools: [MCPTool] = [],
        resources: [MCPResource] = [],
        logHandler: (@Sendable (String) -> Void)? = nil
    ) {
        self.name = name
        self.version = version
        self.description = description
        self.tools = tools
        self.resources = resources
        self.toolsByName = Dictionary(uniqueKeysWithValues: tools.map { ($0.name, $0) })
        self.resourcesByUri = Dictionary(uniqueKeysWithValues: resources.map { ($0.uri, $0) })

        // Default log handler writes to stderr
        if let logHandler {
            self.logHandler = logHandler
        } else {
            let serverName = name
            self.logHandler = { message in
                FileHandle.standardError.write(Data("[\(serverName)] \(message)\n".utf8))
            }
        }
    }

    /// Start the stdio loop. Blocks until stdin closes or receives shutdown signal.
    public func run() async {
        log("MCP server '\(name)' v\(version) starting with \(tools.count) tool(s), \(resources.count) resource(s)")

        setupSignalHandlers()

        do {
            for try await line in FileHandle.standardInput.bytes.lines {
                // Check for cancellation or shutdown signal
                if Task.isCancelled || Self.shouldShutdown.load(ordering: .relaxed) {
                    log("Shutting down gracefully")
                    break
                }

                guard !line.isEmpty else { continue }

                guard let data = line.data(using: .utf8),
                      let request = JSONRPCParser.parse(data) else {
                    write(JSONRPCResponse.error(id: nil, code: MCPConstants.parseError, message: "Parse error"))
                    continue
                }

                // Notifications have no id and expect no response
                if request.isNotification {
                    handleNotification(request)
                    continue
                }

                let response = await handleRequest(request)
                write(response)
            }
        } catch {
            log("stdin error: \(error)")
        }

        log("stdin closed, shutting down")
    }

    // MARK: - Signal Handling

    private func setupSignalHandlers() {
        // Reset shutdown flag
        Self.shouldShutdown.store(false, ordering: .relaxed)

        // Set up signal sources for SIGTERM and SIGINT
        let signals = [SIGTERM, SIGINT]
        for sig in signals {
            signal(sig, SIG_IGN) // Required before using DispatchSource
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler {
                Self.shouldShutdown.store(true, ordering: .relaxed)
            }
            source.resume()
        }
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
            return await handleToolsCall(id: id, paramsDict: request.paramsDict)
        case "resources/list":
            return handleResourcesList(id: id)
        case "resources/read":
            return await handleResourcesRead(id: id, paramsDict: request.paramsDict)
        case "ping":
            return JSONRPCResponse.success(id: id, result: [:] as [String: Any])
        default:
            return JSONRPCResponse.error(id: id, code: MCPConstants.methodNotFound, message: "Method not found: \(request.method)")
        }
    }

    // MARK: - Method Handlers

    private func handleInitialize(id: JSONRPCId) -> Data {
        var capabilities: [String: Any] = [:]

        if !tools.isEmpty {
            capabilities["tools"] = ["listChanged": false] as [String: Any]
        }

        if !resources.isEmpty {
            capabilities["resources"] = ["listChanged": false] as [String: Any]
        }

        // Always support logging
        capabilities["logging"] = [:] as [String: Any]

        let result: [String: Any] = [
            "protocolVersion": MCPConstants.protocolVersion,
            "capabilities": capabilities,
            "serverInfo": {
                var info: [String: Any] = ["name": name, "version": version]
                if let description { info["description"] = description }
                return info
            }() as [String: Any],
        ]
        return JSONRPCResponse.success(id: id, result: result)
    }

    private func handleToolsList(id: JSONRPCId) -> Data {
        let toolDefs = tools.map { $0.definition() }
        let result: [String: Any] = ["tools": toolDefs]
        return JSONRPCResponse.success(id: id, result: result)
    }

    private func handleToolsCall(id: JSONRPCId, paramsDict: [String: Any]) async -> Data {
        guard let toolName = paramsDict["name"] as? String else {
            return JSONRPCResponse.error(id: id, code: MCPConstants.invalidParams, message: "Missing tool name")
        }

        guard let tool = toolsByName[toolName] else {
            return JSONRPCResponse.error(id: id, code: MCPConstants.invalidParams, message: "Unknown tool: \(toolName)")
        }

        let arguments = paramsDict["arguments"] as? [String: Any] ?? [:]

        do {
            let toolResult = try await tool.handler(arguments)
            let result: [String: Any] = [
                "content": toolResult.contentArray,
                "isError": false,
            ]
            return JSONRPCResponse.success(id: id, result: result)
        } catch {
            let result: [String: Any] = [
                "content": [
                    ["type": "text", "text": String(describing: error)] as [String: Any],
                ],
                "isError": true,
            ]
            return JSONRPCResponse.success(id: id, result: result)
        }
    }

    private func handleNotification(_ request: JSONRPCRequest) {
        switch request.method {
        case "notifications/initialized":
            log("Client initialized")
        default:
            log("Unknown notification: \(request.method)")
        }
    }

    private func handleResourcesList(id: JSONRPCId) -> Data {
        let resourceDefs = resources.map { $0.definition() }
        let result: [String: Any] = ["resources": resourceDefs]
        return JSONRPCResponse.success(id: id, result: result)
    }

    private func handleResourcesRead(id: JSONRPCId, paramsDict: [String: Any]) async -> Data {
        guard let uri = paramsDict["uri"] as? String else {
            return JSONRPCResponse.error(id: id, code: MCPConstants.invalidParams, message: "Missing resource uri")
        }

        guard let resource = resourcesByUri[uri] else {
            return JSONRPCResponse.error(id: id, code: MCPConstants.invalidParams, message: "Unknown resource: \(uri)")
        }

        do {
            let contents = try await resource.handler()
            let result: [String: Any] = [
                "contents": [contents.toDict()],
            ]
            return JSONRPCResponse.success(id: id, result: result)
        } catch {
            return JSONRPCResponse.error(id: id, code: MCPConstants.internalError, message: "Resource error: \(String(describing: error))")
        }
    }

    // MARK: - Logging

    /// Send a log message to the client via notifications/message.
    public func sendLog(level: LogLevel, message: String, logger: String? = nil) {
        let notification: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "notifications/message",
            "params": {
                var params: [String: Any] = [
                    "level": level.rawValue,
                    "data": message,
                ]
                if let logger { params["logger"] = logger }
                return params
            }() as [String: Any],
        ]

        if let data = try? JSONSerialization.data(withJSONObject: notification) {
            write(data)
        }
    }

    /// Log levels for MCP logging.
    public enum LogLevel: String, Sendable {
        case debug
        case info
        case notice
        case warning
        case error
        case critical
        case alert
        case emergency
    }

    // MARK: - I/O

    private func write(_ data: Data) {
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }

    private func log(_ message: String) {
        logHandler?(message)
    }
}
