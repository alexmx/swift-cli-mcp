import Foundation

// MARK: - JSON-RPC 2.0 Types

struct JSONRPCRequest {
    let id: JSONRPCId?
    let method: String
    let params: [String: Any]

    var isNotification: Bool { id == nil }
}

enum JSONRPCId: Sendable {
    case int(Int)
    case string(String)

    var jsonValue: Any {
        switch self {
        case .int(let v): v
        case .string(let v): v
        }
    }
}

// MARK: - Parsing

enum JSONRPCParser {
    static func parse(_ data: Data) -> JSONRPCRequest? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let method = json["method"] as? String else {
            return nil
        }

        let id: JSONRPCId?
        if let intId = json["id"] as? Int {
            id = .int(intId)
        } else if let strId = json["id"] as? String {
            id = .string(strId)
        } else {
            id = nil
        }

        let params = json["params"] as? [String: Any] ?? [:]
        return JSONRPCRequest(id: id, method: method, params: params)
    }
}

// MARK: - Response Building

enum JSONRPCResponse {
    static func success(id: JSONRPCId, result: Any) -> Data {
        let response: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id.jsonValue,
            "result": result,
        ]
        return try! JSONSerialization.data(withJSONObject: response)
    }

    static func error(id: JSONRPCId?, code: Int, message: String) -> Data {
        var response: [String: Any] = [
            "jsonrpc": "2.0",
            "error": [
                "code": code,
                "message": message,
            ] as [String: Any],
        ]
        if let id {
            response["id"] = id.jsonValue
        } else {
            response["id"] = NSNull()
        }
        return try! JSONSerialization.data(withJSONObject: response)
    }
}

// MARK: - MCP Protocol Constants

enum MCPConstants {
    static let protocolVersion = "2024-11-05"

    // JSON-RPC error codes
    static let parseError = -32700
    static let methodNotFound = -32601
    static let invalidParams = -32602
}
