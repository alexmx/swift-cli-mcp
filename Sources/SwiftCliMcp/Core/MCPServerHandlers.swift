import Foundation

// MARK: - Parameter Extraction Helper

extension MCPServer {
    /// Error carrying a pre-built JSON-RPC error response.
    private struct ParamError: Error {
        let response: Data
    }

    /// Extract a required parameter from AnyCodable params.
    /// Throws `ParamError` with a ready-to-send response on failure.
    private func extractParam<T>(
        _ params: AnyCodable?,
        key: String,
        id: JSONRPCId,
        errorMessage: String
    ) throws(ParamError) -> T {
        guard let params,
              let paramsDict = params.value as? [String: Any],
              let value = paramsDict[key] as? T
        else {
            throw ParamError(response: JSONRPCResponse.error(
                id: id,
                code: MCPConstants.invalidParams,
                message: errorMessage
            ))
        }
        return value
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
        let name: String
        do {
            name = try extractParam(params, key: "name", id: id, errorMessage: "Missing tool name")
        } catch {
            return error.response
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
        let uri: String
        do {
            uri = try extractParam(params, key: "uri", id: id, errorMessage: "Missing resource uri")
        } catch {
            return error.response
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
