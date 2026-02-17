import Atomics
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
    public let name: String
    public let version: String
    public let description: String?
    public let tools: [MCPTool]
    public let resources: [MCPResource]
    let toolsByName: [String: MCPTool]
    let resourcesByUri: [String: MCPResource]
    let logHandler: (@Sendable (String) -> Void)?

    /// Atomic shutdown flag for signal handling
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
        self.toolsByName = tools.reduce(into: [:]) { dict, tool in
            dict[tool.name] = tool
        }
        self.resourcesByUri = resources.reduce(into: [:]) { dict, resource in
            dict[resource.uri] = resource
        }

        self.logHandler = logHandler
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

    // MARK: - Logging

    /// Send a log message to the client via notifications/message.
    public func sendLog(level: LogLevel, message: String, logger: String? = nil) {
        let notification = LogNotification(
            params: LogMessageParams(
                level: level.rawValue,
                data: message,
                logger: logger
            )
        )

        if let data = try? JSONCoder.encoder.encode(notification) {
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

    func write(_ data: Data) {
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }

    func log(_ message: String) {
        logHandler?(message)
    }
}
