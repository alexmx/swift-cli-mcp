import Foundation
@testable import SwiftMCP
import Testing

@Suite("Resources")
struct ResourceTests {
    @Test("Resource definition")
    func resourceDefinition() {
        let resource = MCPResource(
            uri: "file:///test.txt",
            name: "Test File",
            description: "A test file",
            mimeType: "text/plain"
        ) {
            MCPResourceContents(uri: "file:///test.txt", text: "content")
        }

        let def = resource.definition()
        #expect(def["uri"] as? String == "file:///test.txt")
        #expect(def["name"] as? String == "Test File")
        #expect(def["description"] as? String == "A test file")
        #expect(def["mimeType"] as? String == "text/plain")
    }

    @Test("Resource definition with optional fields")
    func resourceDefinitionOptional() {
        let resource = MCPResource(
            uri: "test://resource",
            name: "Resource"
        ) {
            MCPResourceContents(uri: "test://resource", text: "data")
        }

        let def = resource.definition()
        #expect(def["uri"] as? String == "test://resource")
        #expect(def["name"] as? String == "Resource")
        #expect(def["description"] == nil)
        #expect(def["mimeType"] == nil)
    }

    @Test("Resource contents - text")
    func resourceContentsText() {
        let contents = MCPResourceContents(
            uri: "test://file",
            text: "Hello, world!",
            mimeType: "text/plain"
        )
        let dict = contents.toDict()

        #expect(dict["uri"] as? String == "test://file")
        #expect(dict["text"] as? String == "Hello, world!")
        #expect(dict["mimeType"] as? String == "text/plain")
        #expect(dict["blob"] == nil)
    }

    @Test("Resource contents - blob")
    func resourceContentsBlob() {
        let data = Data([0x01, 0x02, 0x03])
        let contents = MCPResourceContents(
            uri: "test://binary",
            blob: data,
            mimeType: "application/octet-stream"
        )
        let dict = contents.toDict()

        #expect(dict["uri"] as? String == "test://binary")
        #expect(dict["blob"] as? String == data.base64EncodedString())
        #expect(dict["mimeType"] as? String == "application/octet-stream")
        #expect(dict["text"] == nil)
    }

    @Test("Resource handler execution")
    func resourceHandler() async throws {
        let resource = MCPResource(
            uri: "test://dynamic",
            name: "Dynamic"
        ) {
            return MCPResourceContents(uri: "test://dynamic", text: "generated at \(Date())")
        }

        let contents = try await resource.handler()
        #expect(contents.uri == "test://dynamic")
        #expect(contents.text?.starts(with: "generated at") == true)
    }
}
