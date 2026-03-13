import Atomics
import Foundation

/// Serializes all writes to stdout so concurrent request handlers
/// cannot interleave output and produce malformed JSON-RPC messages.
private actor OutputWriter {
    private let handle = FileHandle.standardOutput

    func write(_ data: Data) {
        handle.write(data)
        handle.write(Data("\n".utf8))
    }
}

/// Tracks in-flight request tasks for cancellation and concurrency limiting.
actor TaskTracker {
    private var tasks: [JSONRPCId: Task<Void, Never>] = [:]

    func track(_ id: JSONRPCId, task: Task<Void, Never>) {
        tasks[id] = task
    }

    func remove(_ id: JSONRPCId) {
        tasks.removeValue(forKey: id)
    }

    func cancel(_ id: JSONRPCId, reason: String?) {
        tasks[id]?.cancel()
    }

    var count: Int { tasks.count }

    /// Block until in-flight count drops below `max` by awaiting the first tracked task.
    func waitForSlot(max: Int) async {
        if tasks.count >= max, let (id, task) = tasks.first {
            await task.value
            tasks.removeValue(forKey: id)
        }
    }

    /// Wait for all in-flight tasks to complete.
    func awaitAll() async {
        for (_, task) in tasks {
            await task.value
        }
        tasks.removeAll()
    }
}

/// Stores the minimum log level, adjustable via logging/setLevel.
actor LogLevelStore {
    var level: MCPServer.LogLevel = .debug

    func set(_ level: MCPServer.LogLevel) {
        self.level = level
    }
}

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
    public let resourceTemplates: [MCPResourceTemplate]
    public let prompts: [MCPPrompt]
    let toolsByName: [String: MCPTool]
    let resourcesByUri: [String: MCPResource]
    let promptsByName: [String: MCPPrompt]
    let logHandler: (@Sendable (String) -> Void)?

    /// Atomic shutdown flag for signal handling
    private static let shouldShutdown = ManagedAtomic<Bool>(false)

    /// Shared output writer for serialized stdout access
    private let writer = OutputWriter()

    /// Tracks in-flight request tasks for cancellation support.
    let taskTracker = TaskTracker()

    /// Stores the minimum log level set by the client via logging/setLevel.
    let logLevelStore = LogLevelStore()

    /// Maximum number of concurrent request handlers.
    private let maxConcurrentRequests = 16

    public init(
        name: String,
        version: String,
        description: String? = nil,
        tools: [MCPTool] = [],
        resources: [MCPResource] = [],
        resourceTemplates: [MCPResourceTemplate] = [],
        prompts: [MCPPrompt] = [],
        logHandler: (@Sendable (String) -> Void)? = nil
    ) {
        self.name = name
        self.version = version
        self.description = description
        self.tools = tools
        self.resources = resources
        self.resourceTemplates = resourceTemplates
        self.prompts = prompts
        self.toolsByName = tools.reduce(into: [:]) { dict, tool in
            dict[tool.name] = tool
        }
        self.resourcesByUri = resources.reduce(into: [:]) { dict, resource in
            dict[resource.uri] = resource
        }
        self.promptsByName = prompts.reduce(into: [:]) { dict, prompt in
            dict[prompt.name] = prompt
        }

        self.logHandler = logHandler
    }

    /// Start the stdio loop. Blocks until stdin closes or receives shutdown signal.
    /// Requests are dispatched concurrently so slow tool handlers do not block
    /// other pending requests.
    public func run() async {
        log("MCP server '\(name)' v\(version) starting with \(tools.count) tool(s), \(resources.count) resource(s), \(prompts.count) prompt(s)")

        let signalSources = setupSignalHandlers()
        defer { signalSources.forEach { $0.cancel() } }

        do {
            for try await line in FileHandle.standardInput.bytes.lines {
                // Check for cancellation or shutdown signal
                if Task.isCancelled || Self.shouldShutdown.load(ordering: .relaxed) {
                    log("Shutting down gracefully")
                    break
                }

                guard !line.isEmpty else { continue }

                guard let data = line.data(using: .utf8),
                      let request = JSONRPCParser.parse(data)
                else {
                    await write(JSONRPCResponse.error(id: nil, code: MCPConstants.parseError, message: "Parse error"))
                    continue
                }

                // Notifications have no id and expect no response
                if request.isNotification {
                    await handleNotification(request)
                    continue
                }

                // Apply back-pressure: wait for a slot before dispatching
                await taskTracker.waitForSlot(max: maxConcurrentRequests)

                // Dispatch request handling concurrently so slow tools
                // don't block other incoming requests
                let id = request.id!
                let task = Task {
                    let response = await self.handleRequest(request)
                    await self.taskTracker.remove(id)
                    await self.write(response)
                }
                await taskTracker.track(id, task: task)
            }
        } catch {
            log("stdin error: \(error)")
        }

        // Wait for all in-flight request handlers to finish
        await taskTracker.awaitAll()

        log("stdin closed, shutting down")
    }

    // MARK: - Signal Handling

    private func setupSignalHandlers() -> [DispatchSourceSignal] {
        Self.shouldShutdown.store(false, ordering: .relaxed)

        return [SIGTERM, SIGINT].map { sig in
            signal(sig, SIG_IGN) // Required before using DispatchSource
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler {
                Self.shouldShutdown.store(true, ordering: .relaxed)
                // Close stdin to unblock the async line iteration in run()
                try? FileHandle.standardInput.close()
            }
            source.resume()
            return source
        }
    }

    // MARK: - Logging

    /// Send a log message to the client via notifications/message.
    /// Messages below the minimum level set by `logging/setLevel` are filtered.
    public func sendLog(level: LogLevel, message: String, logger: String? = nil) async {
        let minLevel = await logLevelStore.level
        guard level >= minLevel else { return }

        let notification = LogNotification(
            params: LogMessageParams(
                level: level.rawValue,
                data: message,
                logger: logger
            )
        )

        if let data = try? JSONCoder.encoder.encode(notification) {
            await write(data)
        }
    }

    /// Log levels for MCP logging, ordered by severity (RFC 5424).
    public enum LogLevel: String, Sendable, Comparable {
        case debug
        case info
        case notice
        case warning
        case error
        case critical
        case alert
        case emergency

        private var severity: Int {
            switch self {
            case .debug: 0
            case .info: 1
            case .notice: 2
            case .warning: 3
            case .error: 4
            case .critical: 5
            case .alert: 6
            case .emergency: 7
            }
        }

        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.severity < rhs.severity
        }
    }

    // MARK: - I/O

    func write(_ data: Data) async {
        await writer.write(data)
    }

    func log(_ message: String) {
        logHandler?(message)
    }
}
