import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import SemanticBrowser

final class SpecConformanceTests: XCTestCase {
    func testSnapshotRequiresWaitAndReturnsSpecFields() async throws {
        let svc = SemanticMemoryService()
        let kernel = makeSemanticKernel(service: svc, requireAPIKey: false)
        let server = NIOHTTPServer(kernel: kernel)
        let port = try await server.start(port: 0)

        // Missing wait -> 400
        do {
            var req = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/v1/snapshot")!)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: ["url": "https://example.com"]) 
            let (_, resp) = try await URLSession.shared.data(for: req)
            XCTAssertEqual((resp as? HTTPURLResponse)?.statusCode, 400)
        }

        // With wait -> 200 and expected shape
        do {
            var req = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/v1/snapshot")!)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: [
                "url": "https://example.com",
                "wait": ["strategy": "domContentLoaded", "maxWaitMs": 1000]
            ])
            let (data, resp) = try await URLSession.shared.data(for: req)
            XCTAssertEqual((resp as? HTTPURLResponse)?.statusCode, 200)
            let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let snap = obj?["snapshot"] as? [String: Any]
            XCTAssertNotNil(snap? ["snapshotId"]) 
            let page = snap?["page"] as? [String: Any]
            XCTAssertEqual(page?["status"] as? Int, 200)
            XCTAssertEqual((page?["contentType"] as? String)?.lowercased(), "text/html")
            let rendered = snap?["rendered"] as? [String: Any]
            XCTAssertNotNil(rendered?["html"]) 
            XCTAssertNotNil(rendered?["text"]) 
        }
        try await server.stop()

    }

    func testBrowseIncludesSpans() async throws {
        let svc = SemanticMemoryService()
        let kernel = makeSemanticKernel(service: svc, requireAPIKey: false)
        let server = NIOHTTPServer(kernel: kernel)
        let port = try await server.start(port: 0)

        var req = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/v1/browse")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "url": "https://example.com",
            "wait": ["strategy": "domContentLoaded", "maxWaitMs": 1000],
            "mode": "standard",
            "index": ["enabled": false]
        ])
        let (data, resp) = try await URLSession.shared.data(for: req)
        XCTAssertEqual((resp as? HTTPURLResponse)?.statusCode, 200)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let analysis = obj?["analysis"] as? [String: Any]
        let blocks = analysis?["blocks"] as? [[String: Any]]
        XCTAssertNotNil(blocks)
        XCTAssertTrue(blocks!.contains { ($0["span"] as? [Int]) != nil })

        try await server.stop()

    }

    func testHealthIsSpecOnly() async throws {
        let svc = SemanticMemoryService()
        let kernel = makeSemanticKernel(service: svc, requireAPIKey: false)
        let server = NIOHTTPServer(kernel: kernel)
        let port = try await server.start(port: 0)

        let (data, resp) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:\(port)/v1/health")!)
        XCTAssertEqual((resp as? HTTPURLResponse)?.statusCode, 200)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(obj?["status"] as? String, "ok")
        XCTAssertNotNil(obj?["version"]) 
        XCTAssertNotNil((obj?["browserPool"] as? [String: Any])? ["capacity"]) 
        XCTAssertNil(obj?["capture"])
        XCTAssertNil(obj?["ssrf"])
        try await server.stop()
    }
}

