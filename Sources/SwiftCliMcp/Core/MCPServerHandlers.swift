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
        case "resources/templates/list":
            return handleResourceTemplatesList(id: id)
        case "prompts/list":
            return handlePromptsList(id: id)
        case "prompts/get":
            return await handlePromptsGet(id: id, params: request.params)
        case "logging/setLevel":
            return await handleLoggingSetLevel(id: id, params: request.params)
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

    func handleNotification(_ request: JSONRPCRequest) async {
        switch request.method {
        case "notifications/initialized":
            log("Client initialized")
        case "notifications/cancelled":
            if let paramsDict = request.params?.value as? [String: Any] {
                let reason = paramsDict["reason"] as? String
                // requestId can be int or string
                let requestId: JSONRPCId?
                if let intId = paramsDict["requestId"] as? Int {
                    requestId = .int(intId)
                } else if let strId = paramsDict["requestId"] as? String {
                    requestId = .string(strId)
                } else {
                    requestId = nil
                }
                if let requestId {
                    await taskTracker.cancel(requestId, reason: reason)
                    log("Cancelled request \(requestId)\(reason.map { ": \($0)" } ?? "")")
                }
            }
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
        var promptsCapability: InitializeResponse.Capabilities.PromptsCapability?

        if !tools.isEmpty {
            toolsCapability = InitializeResponse.Capabilities.ToolsCapability(listChanged: false)
        }

        if !resources.isEmpty {
            resourcesCapability = InitializeResponse.Capabilities.ResourcesCapability(listChanged: false)
        }

        if !prompts.isEmpty {
            promptsCapability = InitializeResponse.Capabilities.PromptsCapability(listChanged: false)
        }

        let response = InitializeResponse(
            protocolVersion: MCPConstants.protocolVersion,
            capabilities: InitializeResponse.Capabilities(
                tools: toolsCapability,
                resources: resourcesCapability,
                prompts: promptsCapability,
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

    func handleResourceTemplatesList(id: JSONRPCId) -> Data {
        let templateDefs = resourceTemplates.map { $0.toDefinition() }
        let response = ResourceTemplatesListResponse(resourceTemplates: templateDefs)
        return JSONRPCResponse.success(id: id, result: response)
    }

    func handlePromptsList(id: JSONRPCId) -> Data {
        let promptDefs = prompts.map { $0.toDefinition() }
        let response = PromptsListResponse(prompts: promptDefs)
        return JSONRPCResponse.success(id: id, result: response)
    }

    func handlePromptsGet(id: JSONRPCId, params: AnyCodable?) async -> Data {
        let name: String
        do {
            name = try extractParam(params, key: "name", id: id, errorMessage: "Missing prompt name")
        } catch {
            return error.response
        }

        guard let prompt = promptsByName[name] else {
            return JSONRPCResponse.error(id: id, code: MCPConstants.invalidParams, message: "Unknown prompt: \(name)")
        }

        // Extract arguments (string values only per MCP spec)
        let paramsDict = params?.value as? [String: Any] ?? [:]
        let arguments = (paramsDict["arguments"] as? [String: String]) ?? [:]

        do {
            let result = try await prompt.handler(arguments)
            let messages = result.messages.map { msg -> PromptMessageItem in
                let content: PromptMessageItem.PromptContent
                switch msg.content {
                case .text(let text):
                    content = .text(text)
                case .image(let data, let mimeType):
                    content = .image(data: data.base64EncodedString(), mimeType: mimeType)
                case .resource(let uri, let text, let mimeType):
                    content = .resource(uri: uri, text: text, mimeType: mimeType)
                }
                return PromptMessageItem(role: msg.role.rawValue, content: content)
            }
            let response = PromptGetResponse(
                description: result.description,
                messages: messages
            )
            return JSONRPCResponse.success(id: id, result: response)
        } catch {
            return JSONRPCResponse.error(
                id: id,
                code: MCPConstants.internalError,
                message: "Prompt error: \(String(describing: error))"
            )
        }
    }

    func handleLoggingSetLevel(id: JSONRPCId, params: AnyCodable?) async -> Data {
        let levelStr: String
        do {
            levelStr = try extractParam(params, key: "level", id: id, errorMessage: "Missing level")
        } catch {
            return error.response
        }

        guard let level = MCPServer.LogLevel(rawValue: levelStr) else {
            return JSONRPCResponse.error(
                id: id,
                code: MCPConstants.invalidParams,
                message: "Invalid log level: \(levelStr)"
            )
        }

        await logLevelStore.set(level)
        log("Log level set to \(levelStr)")
        return JSONRPCResponse.success(id: id, result: EmptyObject())
    }
}

// MARK: - Helper Types

/// Empty object for responses that need an empty result
private struct EmptyObject: Codable, Sendable {}
