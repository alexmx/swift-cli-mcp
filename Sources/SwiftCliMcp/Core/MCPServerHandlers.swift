import Foundation

// MARK: - Parameter Extraction Helper

extension MCPServer {
    /// Result type for parameter extraction
    private enum ParamResult<T> {
        case success(T)
        case error(Data)
    }

    /// Extract a required parameter from AnyCodable params
    private func extractParam<T>(
        _ params: AnyCodable?,
        key: String,
        id: JSONRPCId,
        errorMessage: String
    ) -> ParamResult<T> {
        guard let params else {
            return .error(JSONRPCResponse.error(
                id: id,
                code: MCPConstants.invalidParams,
                message: "Missing params"
            ))
        }

        guard let paramsDict = params.value as? [String: Any],
              let value = paramsDict[key] as? T else {
            return .error(JSONRPCResponse.error(
                id: id,
                code: MCPConstants.invalidParams,
                message: errorMessage
            ))
        }

        return .success(value)
    }
}

// MARK: - Request Routing

extension MCPServer {
    func handleRequest(_ request: JSONRPCRequest) async -> Data {
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
        case "resources/list":
            return handleResourcesList(id: id)
        case "resources/read":
            return await handleResourcesRead(id: id, params: request.params)
        case "ping":
            return JSONRPCResponse.success(id: id, result: EmptyObject())
        default:
            return JSONRPCResponse.error(
                id: id,
                code: MCPConstants.methodNotFound,
                message: "Method not found: \(request.method)"
            )
        }
    }

    func handleNotification(_ request: JSONRPCRequest) {
        switch request.method {
        case "notifications/initialized":
            log("Client initialized")
        default:
            log("Unknown notification: \(request.method)")
        }
    }
}

// MARK: - Method Handlers

extension MCPServer {
    func handleInitialize(id: JSONRPCId) -> Data {
        var toolsCapability: InitializeResponse.Capabilities.ToolsCapability?
        var resourcesCapability: InitializeResponse.Capabilities.ResourcesCapability?

        if !tools.isEmpty {
            toolsCapability = InitializeResponse.Capabilities.ToolsCapability(listChanged: false)
        }

        if !resources.isEmpty {
            resourcesCapability = InitializeResponse.Capabilities.ResourcesCapability(listChanged: false)
        }

        let response = InitializeResponse(
            protocolVersion: MCPConstants.protocolVersion,
            capabilities: InitializeResponse.Capabilities(
                tools: toolsCapability,
                resources: resourcesCapability,
                logging: InitializeResponse.Capabilities.LoggingCapability()
            ),
            serverInfo: InitializeResponse.ServerInfo(
                name: name,
                version: version,
                description: description
            )
        )

        return JSONRPCResponse.success(id: id, result: response)
    }

    func handleToolsList(id: JSONRPCId) -> Data {
        let toolDefs = tools.map { $0.toDefinition() }
        let response = ToolsListResponse(tools: toolDefs)
        return JSONRPCResponse.success(id: id, result: response)
    }

    func handleToolsCall(id: JSONRPCId, params: AnyCodable?) async -> Data {
        // Extract tool name using helper
        let name: String
        switch extractParam(params, key: "name", id: id, errorMessage: "Missing tool name") as ParamResult<String> {
        case .success(let value):
            name = value
        case .error(let errorResponse):
            return errorResponse
        }

        guard let tool = toolsByName[name] else {
            return JSONRPCResponse.error(id: id, code: MCPConstants.invalidParams, message: "Unknown tool: \(name)")
        }

        // Serialize arguments to JSON Data for the typed handler
        let paramsDict = params?.value as? [String: Any] ?? [:]
        let argumentsDict = paramsDict["arguments"] as? [String: Any] ?? [:]
        let argumentsData = try? JSONCoder.encoder.encode(AnyCodable(argumentsDict))

        do {
            let toolResult = try await tool.handler(argumentsData ?? Data("{}".utf8))
            let response = ToolCallResponse(
                content: toolResult.contentArray,
                isError: false
            )
            return JSONRPCResponse.success(id: id, result: response)
        } catch {
            let response = ToolCallResponse(
                content: [.text(String(describing: error))],
                isError: true
            )
            return JSONRPCResponse.success(id: id, result: response)
        }
    }

    func handleResourcesList(id: JSONRPCId) -> Data {
        let resourceDefs = resources.map { $0.toDefinition() }
        let response = ResourcesListResponse(resources: resourceDefs)
        return JSONRPCResponse.success(id: id, result: response)
    }

    func handleResourcesRead(id: JSONRPCId, params: AnyCodable?) async -> Data {
        // Extract resource URI using helper
        let uri: String
        switch extractParam(params, key: "uri", id: id, errorMessage: "Missing resource uri") as ParamResult<String> {
        case .success(let value):
            uri = value
        case .error(let errorResponse):
            return errorResponse
        }

        guard let resource = resourcesByUri[uri] else {
            return JSONRPCResponse.error(id: id, code: MCPConstants.invalidParams, message: "Unknown resource: \(uri)")
        }

        do {
            let contents = try await resource.handler()
            let response = ResourcesReadResponse(
                contents: [contents.toProtocolItem()]
            )
            return JSONRPCResponse.success(id: id, result: response)
        } catch {
            return JSONRPCResponse.error(
                id: id,
                code: MCPConstants.internalError,
                message: "Resource error: \(String(describing: error))"
            )
        }
    }
}

// MARK: - Helper Types

/// Empty object for responses that need an empty result
private struct EmptyObject: Codable, Sendable {}
