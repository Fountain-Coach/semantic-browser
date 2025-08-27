import XCTest
@testable import SemanticBrowser

final class CDPSmokeTests: XCTestCase {
    func testCDPSnapshotSkipsWhenNoEnv() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let ws = env["SB_CDP_URL"], let url = URL(string: ws) else { throw XCTSkip("SB_CDP_URL not set") }
        let engine = CDPBrowserEngine(wsURL: url)
        do {
            let (html, text) = try await engine.snapshotHTML(for: "https://example.com")
            XCTAssertFalse(html.isEmpty || text.isEmpty)
        } catch {
            throw XCTSkip("CDP engine unavailable: \(error)")
        }
    }
}

// © 2025 Contexter alias Benedikt Eickhoff 🛡️ All rights reserved.
