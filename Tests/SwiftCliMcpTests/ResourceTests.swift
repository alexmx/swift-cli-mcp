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

        let def = resource.toDefinition()
        #expect(def.uri == "file:///test.txt")
        #expect(def.name == "Test File")
        #expect(def.description == "A test file")
        #expect(def.mimeType == "text/plain")
    }

    @Test("Resource definition with optional fields")
    func resourceDefinitionOptional() {
        let resource = MCPResource(
            uri: "test://resource",
            name: "Resource"
        ) {
            MCPResourceContents(uri: "test://resource", text: "data")
        }

        let def = resource.toDefinition()
        #expect(def.uri == "test://resource")
        #expect(def.name == "Resource")
        #expect(def.description == nil)
        #expect(def.mimeType == nil)
    }

    @Test("Resource contents - text")
    func resourceContentsText() {
        let contents = MCPResourceContents(
            uri: "test://file",
            text: "Hello, world!",
            mimeType: "text/plain"
        )
        let item = contents.toProtocolItem()

        #expect(item.uri == "test://file")
        #expect(item.text == "Hello, world!")
        #expect(item.mimeType == "text/plain")
        #expect(item.blob == nil)
    }

    @Test("Resource contents - blob")
    func resourceContentsBlob() {
        let data = Data([0x01, 0x02, 0x03])
        let contents = MCPResourceContents(
            uri: "test://binary",
            blob: data,
            mimeType: "application/octet-stream"
        )
        let item = contents.toProtocolItem()

        #expect(item.uri == "test://binary")
        #expect(item.blob == data.base64EncodedString())
        #expect(item.mimeType == "application/octet-stream")
        #expect(item.text == nil)
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
