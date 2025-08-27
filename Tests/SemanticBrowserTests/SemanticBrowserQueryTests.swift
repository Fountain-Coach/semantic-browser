import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import SemanticBrowser

final class SemanticBrowserQueryTests: XCTestCase {
    func testQueryPagesSegmentsEntities() async throws {
        let svc = SemanticMemoryService()
        await svc.seed(
            pages: [PageDoc(id: "p1", url: "https://ex.com/a", host: "ex.com", title: "Alpha"), PageDoc(id: "p2", url: "https://ex.com/b", host: "ex.com", title: "Beta")],
            segments: [SegmentDoc(id: "s1", pageId: "p1", kind: "paragraph", text: "hello alpha"), SegmentDoc(id:"s2", pageId: "p2", kind: "heading", text: "beta title")],
            entities: [EntityDoc(id: "e1", name: "Alice", type: "PERSON"), EntityDoc(id: "e2", name: "Bob", type: "PERSON")]
        )
        let kernel = makeSemanticKernel(service: svc)
        let server = NIOHTTPServer(kernel: kernel)
        let port = try await server.start(port: 0)

        do {
            let (data, resp) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:\(port)/v1/pages?q=Alpha")!)
            XCTAssertEqual((resp as? HTTPURLResponse)?.statusCode, 200)
            let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertEqual(obj?["total"] as? Int, 1)

            let (sdata, sresp) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:\(port)/v1/segments?kind=heading")!)
            XCTAssertEqual((sresp as? HTTPURLResponse)?.statusCode, 200)
            let sobj = try JSONSerialization.jsonObject(with: sdata) as? [String: Any]
            XCTAssertEqual(sobj?["total"] as? Int, 1)

            let (edata, eresp) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:\(port)/v1/entities?q=Alice&type=PERSON")!)
            XCTAssertEqual((eresp as? HTTPURLResponse)?.statusCode, 200)
            let eobj = try JSONSerialization.jsonObject(with: edata) as? [String: Any]
            XCTAssertEqual(eobj?["total"] as? Int, 1)
        }
        try await server.stop()
    }
}

// © 2025 Contexter alias Benedikt Eickhoff 🛡️ All rights reserved.
