import Foundation
@testable import SwiftMCP
import Testing

@Suite("Content Types")
struct ContentTests {
    @Test("Text content encoding")
    func textContent() throws {
        let content = MCPContent.text("Hello, world!")

        // Encode to JSON
        let encoder = JSONEncoder()
        let data = try encoder.encode(content)

        // Decode back
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MCPContent.self, from: data)

        guard case .text(let text) = decoded else {
            Issue.record("Expected text content")
            return
        }
        #expect(text == "Hello, world!")
    }

    @Test("Image content encoding")
    func imageContent() throws {
        let data = Data([0x00, 0x01, 0x02])
        let content = MCPContent.image(data: data, mimeType: "image/png")

        // Encode to JSON
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(content)

        // Decode back
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MCPContent.self, from: jsonData)

        guard case .image(let decodedData, let mimeType) = decoded else {
            Issue.record("Expected image content")
            return
        }
        #expect(decodedData == data)
        #expect(mimeType == "image/png")
    }

    @Test("Resource content encoding")
    func resourceContent() throws {
        let content = MCPContent.resource(
            uri: "file:///test.txt",
            mimeType: "text/plain",
            text: "content"
        )

        // Encode to JSON
        let encoder = JSONEncoder()
        let data = try encoder.encode(content)

        // Decode back
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MCPContent.self, from: data)

        guard case .resource(let uri, let mimeType, let text) = decoded else {
            Issue.record("Expected resource content")
            return
        }
        #expect(uri == "file:///test.txt")
        #expect(mimeType == "text/plain")
        #expect(text == "content")
    }

    @Test("Resource content with optional fields")
    func resourceContentOptional() throws {
        let content = MCPContent.resource(uri: "file:///test", mimeType: nil, text: nil)

        // Encode to JSON
        let encoder = JSONEncoder()
        let data = try encoder.encode(content)

        // Decode back
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MCPContent.self, from: data)

        guard case .resource(let uri, let mimeType, let text) = decoded else {
            Issue.record("Expected resource content")
            return
        }
        #expect(uri == "file:///test")
        #expect(mimeType == nil)
        #expect(text == nil)
    }

    // MARK: - Tool Result Tests

    @Test("Tool result - text convenience")
    func toolResultText() {
        let result = MCPToolResult.text("Hello")
        let items = result.contentArray

        #expect(items.count == 1)
        guard case .text(let text) = items[0] else {
            Issue.record("Expected text content item")
            return
        }
        #expect(text == "Hello")
    }

    @Test("Tool result - multiple content blocks")
    func toolResultMultiple() {
        let result = MCPToolResult.content([
            .text("First"),
            .text("Second")
        ])
        let items = result.contentArray

        #expect(items.count == 2)
        guard case .text(let text1) = items[0] else {
            Issue.record("Expected text content item")
            return
        }
        guard case .text(let text2) = items[1] else {
            Issue.record("Expected text content item")
            return
        }
        #expect(text1 == "First")
        #expect(text2 == "Second")
    }
}
