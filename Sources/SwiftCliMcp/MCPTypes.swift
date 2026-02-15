import Foundation

// MARK: - AnyCodable Helper

/// Type-erased Codable wrapper for dynamic JSON values.
/// @unchecked Sendable because the value is constrained to JSON types via Codable.
struct AnyCodable: Codable, @unchecked Sendable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON type"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Unsupported type"
                )
            )
        }
    }
}

// MARK: - JSON-RPC 2.0 Types

enum JSONRPCId: Codable, Sendable, Hashable {
    case int(Int)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "ID must be int or string"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let v):
            try container.encode(v)
        case .string(let v):
            try container.encode(v)
        }
    }
}

struct JSONRPCRequest: Codable, Sendable {
    let jsonrpc: String?
    let id: JSONRPCId?
    let method: String
    let params: AnyCodable?

    var isNotification: Bool {
        id == nil
    }

    var paramsDict: [String: Any] {
        params?.value as? [String: Any] ?? [:]
    }
}

struct JSONRPCSuccessResponse: Codable, Sendable {
    let jsonrpc: String
    let id: JSONRPCId
    let result: AnyCodable

    init(id: JSONRPCId, result: Any) {
        self.jsonrpc = "2.0"
        self.id = id
        self.result = AnyCodable(result)
    }
}

struct JSONRPCErrorResponse: Codable, Sendable {
    let jsonrpc: String
    let id: JSONRPCId?
    let error: ErrorDetail

    struct ErrorDetail: Codable, Sendable {
        let code: Int
        let message: String
    }

    init(id: JSONRPCId?, code: Int, message: String) {
        self.jsonrpc = "2.0"
        self.id = id
        self.error = ErrorDetail(code: code, message: message)
    }
}

// MARK: - Parsing

enum JSONRPCParser {
    static func parse(_ data: Data) -> JSONRPCRequest? {
        guard let request = try? JSONDecoder().decode(JSONRPCRequest.self, from: data) else {
            return nil
        }

        // Validate JSON-RPC 2.0 version field (required by spec)
        // Allow missing field for leniency, but reject wrong versions
        if let version = request.jsonrpc, version != "2.0" {
            return nil
        }

        return request
    }
}

// MARK: - Response Building

enum JSONRPCResponse {
    private static let encoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.outputFormatting = []
        return enc
    }()

    static func success(id: JSONRPCId, result: Any) -> Data {
        let response = JSONRPCSuccessResponse(id: id, result: result)
        do {
            return try encoder.encode(response)
        } catch {
            // Hardcoded fallback — always valid, no serialization needed
            let fallback = #"{"jsonrpc":"2.0","id":null,"error":{"code":-32603,"message":"Internal serialization error"}}"#
            return Data(fallback.utf8)
        }
    }

    static func error(id: JSONRPCId?, code: Int, message: String) -> Data {
        let response = JSONRPCErrorResponse(id: id, code: code, message: message)
        do {
            return try encoder.encode(response)
        } catch {
            // Hardcoded fallback — always valid, no serialization needed
            let fallback = #"{"jsonrpc":"2.0","id":null,"error":{"code":-32603,"message":"Internal serialization error"}}"#
            return Data(fallback.utf8)
        }
    }
}

// MARK: - MCP Protocol Constants

enum MCPConstants {
    static let protocolVersion = "2024-11-05"

    // JSON-RPC error codes
    static let parseError = -32700
    static let methodNotFound = -32601
    static let invalidParams = -32602
    static let internalError = -32603
}
