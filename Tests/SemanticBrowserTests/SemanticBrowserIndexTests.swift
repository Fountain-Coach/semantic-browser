import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import SemanticBrowser

final class SemanticBrowserIndexTests: XCTestCase {
    func testIndexThenQuery() async throws {
        let svc = SemanticMemoryService()
        let kernel = makeSemanticKernel(service: svc)
        let server = NIOHTTPServer(kernel: kernel)
        let port = try await server.start(port: 0)

        // Ingest one page with segments and entities
        let payload: [String: Any] = [
            "analysis": [
                "page": ["id": "pZ", "url": "https://ex.com/z", "host": "ex.com", "title": "Zeta"],
                "segments": [
                    ["id": "sz1", "pageId": "pZ", "kind": "heading", "text": "Z title"],
                    ["id": "sz2", "pageId": "pZ", "kind": "paragraph", "text": "content z"]
                ],
                "entities": [
                    ["id": "ez1", "name": "Zed", "type": "PERSON"]
                ]
            ]
        ]
        var req = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/v1/index")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (_, resp) = try await URLSession.shared.data(for: req)
        XCTAssertEqual((resp as? HTTPURLResponse)?.statusCode, 200)

        // Query pages to see Zeta
        let (data, r) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:\(port)/v1/pages?q=Zeta")!)
        XCTAssertEqual((r as? HTTPURLResponse)?.statusCode, 200)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(obj?["total"] as? Int, 1)

        try await server.stop()
    }
}

// © 2025 Contexter alias Benedikt Eickhoff 🛡️ All rights reserved.
