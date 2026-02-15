import Foundation
@testable import SwiftMCP
import Testing

@Suite("Content Types")
struct ContentTests {
    @Test("Text content encoding")
    func textContent() {
        let content = MCPContent.text("Hello, world!")
        let dict = content.toDict()

        #expect(dict["type"] as? String == "text")
        #expect(dict["text"] as? String == "Hello, world!")
    }

    @Test("Image content encoding")
    func imageContent() {
        let data = Data([0x00, 0x01, 0x02])
        let content = MCPContent.image(data: data, mimeType: "image/png")
        let dict = content.toDict()

        #expect(dict["type"] as? String == "image")
        #expect(dict["mimeType"] as? String == "image/png")
        #expect(dict["data"] as? String == data.base64EncodedString())
    }

    @Test("Resource content encoding")
    func resourceContent() {
        let content = MCPContent.resource(
            uri: "file:///test.txt",
            mimeType: "text/plain",
            text: "content"
        )
        let dict = content.toDict()

        #expect(dict["type"] as? String == "resource")
        #expect(dict["uri"] as? String == "file:///test.txt")
        #expect(dict["mimeType"] as? String == "text/plain")
        #expect(dict["text"] as? String == "content")
    }

    @Test("Resource content with optional fields")
    func resourceContentOptional() {
        let content = MCPContent.resource(uri: "file:///test", mimeType: nil, text: nil)
        let dict = content.toDict()

        #expect(dict["type"] as? String == "resource")
        #expect(dict["uri"] as? String == "file:///test")
        #expect(dict["mimeType"] == nil)
        #expect(dict["text"] == nil)
    }

    // MARK: - Tool Result Tests

    @Test("Tool result - text convenience")
    func toolResultText() {
        let result = MCPToolResult.text("Hello")
        let array = result.contentArray

        #expect(array.count == 1)
        #expect(array[0]["type"] as? String == "text")
        #expect(array[0]["text"] as? String == "Hello")
    }

    @Test("Tool result - multiple content blocks")
    func toolResultMultiple() {
        let result = MCPToolResult.content([
            .text("First"),
            .text("Second")
        ])
        let array = result.contentArray

        #expect(array.count == 2)
        #expect(array[0]["text"] as? String == "First")
        #expect(array[1]["text"] as? String == "Second")
    }
}
