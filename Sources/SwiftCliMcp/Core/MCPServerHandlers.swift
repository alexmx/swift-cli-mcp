import Foundation

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
            return await handleToolsCall(id: id, paramsDict: request.paramsDict)
        case "resources/list":
            return handleResourcesList(id: id)
        case "resources/read":
            return await handleResourcesRead(id: id, paramsDict: request.paramsDict)
        case "ping":
            return JSONRPCResponse.success(id: id, result: [:] as [String: Any])
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
            }() as [String: Any]
        ]
        return JSONRPCResponse.success(id: id, result: result)
    }

    func handleToolsList(id: JSONRPCId) -> Data {
        let toolDefs = tools.map { $0.definition() }
        let result: [String: Any] = ["tools": toolDefs]
        return JSONRPCResponse.success(id: id, result: result)
    }

    func handleToolsCall(id: JSONRPCId, paramsDict: [String: Any]) async -> Data {
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
                "isError": false
            ]
            return JSONRPCResponse.success(id: id, result: result)
        } catch {
            let result: [String: Any] = [
                "content": [
                    ["type": "text", "text": String(describing: error)] as [String: Any]
                ],
                "isError": true
            ]
            return JSONRPCResponse.success(id: id, result: result)
        }
    }

    func handleResourcesList(id: JSONRPCId) -> Data {
        let resourceDefs = resources.map { $0.definition() }
        let result: [String: Any] = ["resources": resourceDefs]
        return JSONRPCResponse.success(id: id, result: result)
    }

    func handleResourcesRead(id: JSONRPCId, paramsDict: [String: Any]) async -> Data {
        guard let uri = paramsDict["uri"] as? String else {
            return JSONRPCResponse.error(id: id, code: MCPConstants.invalidParams, message: "Missing resource uri")
        }

        guard let resource = resourcesByUri[uri] else {
            return JSONRPCResponse.error(id: id, code: MCPConstants.invalidParams, message: "Unknown resource: \(uri)")
        }

        do {
            let contents = try await resource.handler()
            let result: [String: Any] = [
                "contents": [contents.toDict()]
            ]
            return JSONRPCResponse.success(id: id, result: result)
        } catch {
            return JSONRPCResponse.error(
                id: id,
                code: MCPConstants.internalError,
                message: "Resource error: \(String(describing: error))"
            )
        }
    }
}
