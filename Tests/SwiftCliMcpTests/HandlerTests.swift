import Foundation
@testable import SwiftMCP
import Testing

/// Helper to decode a JSON-RPC response from raw Data.
private func decodeResponse(_ data: Data) throws -> [String: Any] {
    try JSONSerialization.jsonObject(with: data) as! [String: Any]
}

/// Helper to build a JSONRPCRequest by parsing JSON, matching the real code path.
private func request(_ json: String) -> JSONRPCRequest {
    JSONRPCParser.parse(json.data(using: .utf8)!)!
}

/// Helper to encode a dictionary to JSON Data for tool handlers.
private func jsonData(_ dict: [String: Any]) -> Data {
    try! JSONCoder.encoder.encode(AnyCodable(dict))
}

// MARK: - Test Server Factory

private func makeServer() -> MCPServer {
    struct EchoArgs: MCPToolInput {
        @InputProperty("The message to echo")
        var message: String
    }

    struct DivideArgs: MCPToolInput {
        @InputProperty("First number")
        var a: Double

        @InputProperty("Second number")
        var b: Double
    }

    return MCPServer(
        name: "test-server",
        version: "1.0.0",
        description: "Test server",
        tools: [
            .tool(name: "echo", description: "Echo back the input") { (args: EchoArgs) in
                .text("Echo: \(args.message)")
            },

            .tool(name: "divide", description: "Divide two numbers") { (args: DivideArgs) in
                guard args.b != 0 else {
                    throw NSError(
                        domain: "test",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Division by zero"]
                    )
                }
                return .text("Result: \(args.a / args.b)")
            },

            .tool(name: "ping", description: "Ping") {
                .text("pong")
            },

            .tool(name: "greet", description: "Greet by name", argumentName: "name", argumentDescription: "Name to greet") { name in
                .text("Hello, \(name)!")
            }
        ],
        resources: [
            .resource(uri: "test://readme", name: "README", description: "A readme", mimeType: "text/plain") { _ in
                "# README"
            },

            .resource(uri: "test://failing", name: "Failing", description: "Always fails") {
                throw NSError(domain: "test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Resource error"])
            }
        ],
        resourceTemplates: [
            .template(uriTemplate: "file:///{path}", name: "Project Files", description: "Read any project file", mimeType: "text/plain"),
            .template(uriTemplate: "db:///{table}/{id}", name: "Database Records", description: "Read a database record")
        ],
        prompts: [
            .prompt(
                name: "code_review",
                description: "Review code for issues",
                arguments: [
                    .required(name: "code", description: "The code to review"),
                    .optional(name: "language", description: "Programming language")
                ]
            ) { args in
                let code = args["code"] ?? ""
                let lang = args["language"] ?? "unknown"
                return .userMessage("Review this \(lang) code:\n\(code)", description: "Code review prompt")
            },

            .prompt(name: "summarize", description: "Summarize text") { _ in
                .result(messages: [
                    .user("Summarize the following."),
                    .assistant("I'll summarize that for you.")
                ])
            }
        ]
    )
}

// MARK: - Initialize

@Suite("Request Handlers")
struct HandlerTests {
    let server = makeServer()

    @Test("initialize returns server info and capabilities")
    func initialize() async throws {
        let response = await server.handleRequest(
            request(#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}"#)
        )
        let json = try decodeResponse(response)

        #expect(json["jsonrpc"] as? String == "2.0")
        #expect(json["id"] as? Int == 1)

        let result = try #require(json["result"] as? [String: Any])
        #expect(result["protocolVersion"] as? String == "2024-11-05")

        let serverInfo = try #require(result["serverInfo"] as? [String: Any])
        #expect(serverInfo["name"] as? String == "test-server")
        #expect(serverInfo["version"] as? String == "1.0.0")

        let capabilities = try #require(result["capabilities"] as? [String: Any])
        #expect(capabilities["tools"] != nil)
        #expect(capabilities["resources"] != nil)
        #expect(capabilities["logging"] != nil)
    }

    // MARK: - Tools

    @Test("tools/list returns all registered tools")
    func toolsList() async throws {
        let response = await server.handleRequest(
            request(#"{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}"#)
        )
        let json = try decodeResponse(response)
        let result = try #require(json["result"] as? [String: Any])
        let tools = try #require(result["tools"] as? [[String: Any]])

        #expect(tools.count == 4)
        let names = tools.compactMap { $0["name"] as? String }
        #expect(names.contains("echo"))
        #expect(names.contains("divide"))
        #expect(names.contains("ping"))
        #expect(names.contains("greet"))
    }

    @Test("tools/call with valid arguments returns result")
    func toolsCallSuccess() async throws {
        let response = await server.handleRequest(
            request(#"{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"echo","arguments":{"message":"hello"}}}"#)
        )
        let json = try decodeResponse(response)
        let result = try #require(json["result"] as? [String: Any])

        #expect(result["isError"] as? Bool == false)
        let content = try #require(result["content"] as? [[String: Any]])
        #expect(content[0]["text"] as? String == "Echo: hello")
    }

    @Test("tools/call with handler error returns isError true")
    func toolsCallError() async throws {
        let response = await server.handleRequest(
            request(#"{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"divide","arguments":{"a":1,"b":0}}}"#)
        )
        let json = try decodeResponse(response)
        let result = try #require(json["result"] as? [String: Any])

        #expect(result["isError"] as? Bool == true)
        let content = try #require(result["content"] as? [[String: Any]])
        let text = try #require(content[0]["text"] as? String)
        #expect(text.contains("Division by zero"))
    }

    @Test("tools/call with unknown tool returns error")
    func toolsCallUnknown() async throws {
        let response = await server.handleRequest(
            request(#"{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"nonexistent","arguments":{}}}"#)
        )
        let json = try decodeResponse(response)
        let error = try #require(json["error"] as? [String: Any])

        #expect(error["code"] as? Int == MCPConstants.invalidParams)
        #expect((error["message"] as? String)?.contains("nonexistent") == true)
    }

    @Test("tools/call with missing name returns error")
    func toolsCallMissingName() async throws {
        let response = await server.handleRequest(
            request(#"{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{}}"#)
        )
        let json = try decodeResponse(response)
        let error = try #require(json["error"] as? [String: Any])

        #expect(error["code"] as? Int == MCPConstants.invalidParams)
    }

    // MARK: - Resources

    @Test("resources/list returns all registered resources")
    func resourcesList() async throws {
        let response = await server.handleRequest(
            request(#"{"jsonrpc":"2.0","id":7,"method":"resources/list","params":{}}"#)
        )
        let json = try decodeResponse(response)
        let result = try #require(json["result"] as? [String: Any])
        let resources = try #require(result["resources"] as? [[String: Any]])

        #expect(resources.count == 2)
        let uris = resources.compactMap { $0["uri"] as? String }
        #expect(uris.contains("test://readme"))
        #expect(uris.contains("test://failing"))
    }

    @Test("resources/read with valid URI returns contents")
    func resourcesReadSuccess() async throws {
        let response = await server.handleRequest(
            request(#"{"jsonrpc":"2.0","id":8,"method":"resources/read","params":{"uri":"test://readme"}}"#)
        )
        let json = try decodeResponse(response)
        let result = try #require(json["result"] as? [String: Any])
        let contents = try #require(result["contents"] as? [[String: Any]])

        #expect(contents[0]["text"] as? String == "# README")
        #expect(contents[0]["uri"] as? String == "test://readme")
    }

    @Test("resources/read with unknown URI returns error")
    func resourcesReadUnknown() async throws {
        let response = await server.handleRequest(
            request(#"{"jsonrpc":"2.0","id":9,"method":"resources/read","params":{"uri":"test://nope"}}"#)
        )
        let json = try decodeResponse(response)
        let error = try #require(json["error"] as? [String: Any])

        #expect(error["code"] as? Int == MCPConstants.invalidParams)
    }

    @Test("resources/read with failing handler returns error")
    func resourcesReadFailing() async throws {
        let response = await server.handleRequest(
            request(#"{"jsonrpc":"2.0","id":10,"method":"resources/read","params":{"uri":"test://failing"}}"#)
        )
        let json = try decodeResponse(response)
        let error = try #require(json["error"] as? [String: Any])

        #expect(error["code"] as? Int == MCPConstants.internalError)
        #expect((error["message"] as? String)?.contains("Resource error") == true)
    }

    @Test("resources/read with missing URI returns error")
    func resourcesReadMissingUri() async throws {
        let response = await server.handleRequest(
            request(#"{"jsonrpc":"2.0","id":11,"method":"resources/read","params":{}}"#)
        )
        let json = try decodeResponse(response)
        let error = try #require(json["error"] as? [String: Any])

        #expect(error["code"] as? Int == MCPConstants.invalidParams)
    }

    // MARK: - Ping & Unknown Method

    @Test("ping returns empty result")
    func ping() async throws {
        let response = await server.handleRequest(
            request(#"{"jsonrpc":"2.0","id":12,"method":"ping","params":{}}"#)
        )
        let json = try decodeResponse(response)

        #expect(json["result"] != nil)
        #expect(json["error"] == nil)
    }

    @Test("unknown method returns method not found error")
    func unknownMethod() async throws {
        let response = await server.handleRequest(
            request(#"{"jsonrpc":"2.0","id":13,"method":"foo/bar","params":{}}"#)
        )
        let json = try decodeResponse(response)
        let error = try #require(json["error"] as? [String: Any])

        #expect(error["code"] as? Int == MCPConstants.methodNotFound)
        #expect((error["message"] as? String)?.contains("foo/bar") == true)
    }

    // MARK: - Convenience Initializers

    @Test("no-argument tool works end-to-end")
    func noArgTool() async throws {
        let result = try await server.toolsByName["ping"]!.handler(jsonData([:]))
        guard case .text(let text) = result else {
            Issue.record("Expected text result")
            return
        }
        #expect(text == "pong")
    }

    @Test("single-string-argument tool works end-to-end")
    func singleStringArgTool() async throws {
        let result = try await server.toolsByName["greet"]!.handler(jsonData(["name": "World"]))
        guard case .text(let text) = result else {
            Issue.record("Expected text result")
            return
        }
        #expect(text == "Hello, World!")
    }

    @Test("single-string-argument tool with missing arg returns error")
    func singleStringArgMissing() async throws {
        do {
            _ = try await server.toolsByName["greet"]!.handler(jsonData([:]))
            Issue.record("Should have thrown")
        } catch {
            #expect(String(describing: error).contains("Missing required argument"))
        }
    }

    // MARK: - Resource Templates

    @Test("resources/templates/list returns all registered templates")
    func resourceTemplatesList() async throws {
        let response = await server.handleRequest(
            request(#"{"jsonrpc":"2.0","id":40,"method":"resources/templates/list","params":{}}"#)
        )
        let json = try decodeResponse(response)
        let result = try #require(json["result"] as? [String: Any])
        let templates = try #require(result["resourceTemplates"] as? [[String: Any]])

        #expect(templates.count == 2)
        let uris = templates.compactMap { $0["uriTemplate"] as? String }
        #expect(uris.contains("file:///{path}"))
        #expect(uris.contains("db:///{table}/{id}"))
    }

    @Test("resources/templates/list includes template metadata")
    func resourceTemplatesMetadata() async throws {
        let response = await server.handleRequest(
            request(#"{"jsonrpc":"2.0","id":41,"method":"resources/templates/list","params":{}}"#)
        )
        let json = try decodeResponse(response)
        let result = try #require(json["result"] as? [String: Any])
        let templates = try #require(result["resourceTemplates"] as? [[String: Any]])

        let fileTemplate = try #require(templates.first { $0["uriTemplate"] as? String == "file:///{path}" })
        #expect(fileTemplate["name"] as? String == "Project Files")
        #expect(fileTemplate["description"] as? String == "Read any project file")
        #expect(fileTemplate["mimeType"] as? String == "text/plain")

        let dbTemplate = try #require(templates.first { $0["uriTemplate"] as? String == "db:///{table}/{id}" })
        #expect(dbTemplate["name"] as? String == "Database Records")
        #expect(dbTemplate["mimeType"] == nil)
    }

    // MARK: - Prompts

    @Test("prompts/list returns all registered prompts")
    func promptsList() async throws {
        let response = await server.handleRequest(
            request(#"{"jsonrpc":"2.0","id":20,"method":"prompts/list","params":{}}"#)
        )
        let json = try decodeResponse(response)
        let result = try #require(json["result"] as? [String: Any])
        let prompts = try #require(result["prompts"] as? [[String: Any]])

        #expect(prompts.count == 2)
        let names = prompts.compactMap { $0["name"] as? String }
        #expect(names.contains("code_review"))
        #expect(names.contains("summarize"))

        // Verify arguments are included
        let codeReview = try #require(prompts.first { $0["name"] as? String == "code_review" })
        let args = try #require(codeReview["arguments"] as? [[String: Any]])
        #expect(args.count == 2)
        #expect(args[0]["name"] as? String == "code")
        #expect(args[0]["required"] as? Bool == true)
    }

    @Test("prompts/get with valid name and arguments returns messages")
    func promptsGetSuccess() async throws {
        let response = await server.handleRequest(
            request(#"{"jsonrpc":"2.0","id":21,"method":"prompts/get","params":{"name":"code_review","arguments":{"code":"fn main()","language":"rust"}}}"#)
        )
        let json = try decodeResponse(response)
        let result = try #require(json["result"] as? [String: Any])

        #expect(result["description"] as? String == "Code review prompt")
        let messages = try #require(result["messages"] as? [[String: Any]])
        #expect(messages.count == 1)
        #expect(messages[0]["role"] as? String == "user")

        let content = try #require(messages[0]["content"] as? [String: Any])
        #expect(content["type"] as? String == "text")
        let text = try #require(content["text"] as? String)
        #expect(text.contains("rust"))
        #expect(text.contains("fn main()"))
    }

    @Test("prompts/get with multiple messages returns all roles")
    func promptsGetMultipleMessages() async throws {
        let response = await server.handleRequest(
            request(#"{"jsonrpc":"2.0","id":22,"method":"prompts/get","params":{"name":"summarize"}}"#)
        )
        let json = try decodeResponse(response)
        let result = try #require(json["result"] as? [String: Any])
        let messages = try #require(result["messages"] as? [[String: Any]])

        #expect(messages.count == 2)
        #expect(messages[0]["role"] as? String == "user")
        #expect(messages[1]["role"] as? String == "assistant")
    }

    @Test("prompts/get with unknown name returns error")
    func promptsGetUnknown() async throws {
        let response = await server.handleRequest(
            request(#"{"jsonrpc":"2.0","id":23,"method":"prompts/get","params":{"name":"nonexistent"}}"#)
        )
        let json = try decodeResponse(response)
        let error = try #require(json["error"] as? [String: Any])

        #expect(error["code"] as? Int == MCPConstants.invalidParams)
        #expect((error["message"] as? String)?.contains("nonexistent") == true)
    }

    @Test("prompts/get with missing name returns error")
    func promptsGetMissingName() async throws {
        let response = await server.handleRequest(
            request(#"{"jsonrpc":"2.0","id":24,"method":"prompts/get","params":{}}"#)
        )
        let json = try decodeResponse(response)
        let error = try #require(json["error"] as? [String: Any])

        #expect(error["code"] as? Int == MCPConstants.invalidParams)
    }

    // MARK: - Logging

    @Test("logging/setLevel with valid level returns empty result")
    func loggingSetLevel() async throws {
        let response = await server.handleRequest(
            request(#"{"jsonrpc":"2.0","id":30,"method":"logging/setLevel","params":{"level":"warning"}}"#)
        )
        let json = try decodeResponse(response)

        #expect(json["result"] != nil)
        #expect(json["error"] == nil)
    }

    @Test("logging/setLevel with invalid level returns error")
    func loggingSetLevelInvalid() async throws {
        let response = await server.handleRequest(
            request(#"{"jsonrpc":"2.0","id":31,"method":"logging/setLevel","params":{"level":"verbose"}}"#)
        )
        let json = try decodeResponse(response)
        let error = try #require(json["error"] as? [String: Any])

        #expect(error["code"] as? Int == MCPConstants.invalidParams)
        #expect((error["message"] as? String)?.contains("verbose") == true)
    }

    @Test("logging/setLevel with missing level returns error")
    func loggingSetLevelMissing() async throws {
        let response = await server.handleRequest(
            request(#"{"jsonrpc":"2.0","id":32,"method":"logging/setLevel","params":{}}"#)
        )
        let json = try decodeResponse(response)
        let error = try #require(json["error"] as? [String: Any])

        #expect(error["code"] as? Int == MCPConstants.invalidParams)
    }

    // MARK: - Capabilities

    @Test("initialize includes prompts capability when prompts registered")
    func initializeWithPrompts() async throws {
        let response = await server.handleRequest(
            request(#"{"jsonrpc":"2.0","id":25,"method":"initialize","params":{}}"#)
        )
        let json = try decodeResponse(response)
        let result = try #require(json["result"] as? [String: Any])
        let capabilities = try #require(result["capabilities"] as? [String: Any])

        #expect(capabilities["prompts"] != nil)
    }
}
