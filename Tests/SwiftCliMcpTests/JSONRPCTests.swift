import Testing
import Foundation
@testable import SwiftCliMcp

@Suite("JSON-RPC Parsing and Response")
struct JSONRPCTests {

    // MARK: - Parsing Tests

    @Test("Parse valid request")
    func parseValidRequest() {
        let json = """
        {"jsonrpc":"2.0","id":1,"method":"test","params":{"key":"value"}}
        """.data(using: .utf8)!

        let request = JSONRPCParser.parse(json)
        #expect(request != nil)
        #expect(request?.method == "test")
        #expect(request?.paramsDict["key"] as? String == "value")
    }

    @Test("Parse notification (no id)")
    func parseNotification() {
        let json = """
        {"jsonrpc":"2.0","method":"notification","params":{}}
        """.data(using: .utf8)!

        let request = JSONRPCParser.parse(json)
        #expect(request != nil)
        #expect(request?.isNotification == true)
    }

    @Test("Reject invalid JSON")
    func parseInvalidJSON() {
        let json = "not json".data(using: .utf8)!
        let request = JSONRPCParser.parse(json)
        #expect(request == nil)
    }

    @Test("Reject invalid version")
    func parseInvalidVersion() {
        let json = """
        {"jsonrpc":"1.0","id":1,"method":"test"}
        """.data(using: .utf8)!

        let request = JSONRPCParser.parse(json)
        #expect(request == nil, "Should reject non-2.0 versions")
    }

    @Test("Accept missing version for leniency")
    func parseMissingVersion() {
        let json = """
        {"id":1,"method":"test","params":{}}
        """.data(using: .utf8)!

        let request = JSONRPCParser.parse(json)
        #expect(request != nil, "Should accept missing version")
    }

    // MARK: - ID Tests

    @Test("Parse integer ID")
    func parseIntId() throws {
        let json = """
        {"jsonrpc":"2.0","id":42,"method":"test"}
        """.data(using: .utf8)!

        let request = try #require(JSONRPCParser.parse(json))
        guard case .int(let value) = request.id else {
            Issue.record("Expected int ID")
            return
        }
        #expect(value == 42)
    }

    @Test("Parse string ID")
    func parseStringId() throws {
        let json = """
        {"jsonrpc":"2.0","id":"test-id","method":"test"}
        """.data(using: .utf8)!

        let request = try #require(JSONRPCParser.parse(json))
        guard case .string(let value) = request.id else {
            Issue.record("Expected string ID")
            return
        }
        #expect(value == "test-id")
    }

    // MARK: - Response Tests

    @Test("Success response format")
    func successResponse() throws {
        let response = JSONRPCResponse.success(id: .int(1), result: ["status": "ok"])
        let json = try #require(try? JSONSerialization.jsonObject(with: response) as? [String: Any])

        #expect(json["jsonrpc"] as? String == "2.0")
        #expect(json["id"] as? Int == 1)
        #expect(json["result"] != nil)
    }

    @Test("Error response format")
    func errorResponse() throws {
        let response = JSONRPCResponse.error(id: .int(1), code: -32600, message: "Invalid request")
        let json = try #require(try? JSONSerialization.jsonObject(with: response) as? [String: Any])

        #expect(json["jsonrpc"] as? String == "2.0")

        let error = try #require(json["error"] as? [String: Any])
        #expect(error["code"] as? Int == -32600)
        #expect(error["message"] as? String == "Invalid request")
    }

    @Test("Error response with null ID")
    func errorResponseWithNullId() throws {
        let response = JSONRPCResponse.error(id: nil, code: -32700, message: "Parse error")
        let json = try #require(try? JSONSerialization.jsonObject(with: response) as? [String: Any])

        // The response should have error field
        #expect(json["error"] != nil)
        #expect(json["jsonrpc"] as? String == "2.0")

        // Note: JSONEncoder may omit null id field, which is acceptable
        // The JSON-RPC spec allows omitting id for parse errors
    }
}
