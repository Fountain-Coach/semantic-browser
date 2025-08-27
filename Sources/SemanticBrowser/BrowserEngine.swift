import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// Forward declaration for options type
// Uses APIModels.WaitPolicy from ModelsAPI.swift in this module
public struct SnapshotResult: Sendable {
    public let html: String
    public let text: String
    public let finalURL: String
    public let loadMs: Int?
    public let network: [APIModels.Snapshot.Network.Request]?
    public let pageStatus: Int?
    public let pageContentType: String?
    public let adminNetwork: [AdminNetworkRequest]?
}

public protocol BrowserEngine: Sendable {
    func snapshotHTML(for url: String) async throws -> (html: String, text: String)
    func snapshot(for url: String, wait: APIModels.WaitPolicy?, capture: CaptureOptions?) async throws -> SnapshotResult
}

public enum BrowserError: Error { case invalidURL, fetchFailed }

public struct URLFetchBrowserEngine: BrowserEngine {
    public init() {}
    public func snapshotHTML(for url: String) async throws -> (html: String, text: String) {
        let res = try await snapshot(for: url, wait: nil, capture: nil)
        return (res.html, res.text)
    }
    public func snapshot(for url: String, wait: APIModels.WaitPolicy?, capture: CaptureOptions?) async throws -> SnapshotResult {
        guard let u = URL(string: url) else { throw BrowserError.invalidURL }
        let start = Date()
        let (data, resp) = try await URLSession.shared.data(from: u)
        let elapsed = Int(Date().timeIntervalSince(start) * 1000.0)
        let html = String(data: data, encoding: .utf8) ?? ""
        let text = html.removingHTMLTags()
        let final = (resp.url?.absoluteString) ?? url
        var contentType: String? = nil
        if let http = resp as? HTTPURLResponse {
            contentType = http.allHeaderFields["Content-Type"] as? String
        }
        if let ct = contentType, let semi = ct.firstIndex(of: ";") { contentType = String(ct[..<semi]) }
        let status = (resp as? HTTPURLResponse)?.statusCode
        return SnapshotResult(html: html, text: text, finalURL: final, loadMs: elapsed, network: nil, pageStatus: status, pageContentType: contentType, adminNetwork: nil)
    }
}

public struct ShellBrowserEngine: BrowserEngine {
    let binary: String
    let args: [String]
    public init(binary: String, args: [String] = []) { self.binary = binary; self.args = args }
    public func snapshotHTML(for url: String) async throws -> (html: String, text: String) {
        let res = try await snapshot(for: url, wait: nil, capture: nil)
        return (res.html, res.text)
    }
    public func snapshot(for url: String, wait: APIModels.WaitPolicy?, capture: CaptureOptions?) async throws -> SnapshotResult {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binary)
        proc.arguments = args + [url]
        let pipe = Pipe()
        proc.standardOutput = pipe
        let start = Date()
        try proc.run()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else { throw BrowserError.fetchFailed }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let html = String(data: data, encoding: .utf8) ?? ""
        let text = html.removingHTMLTags()
        let elapsed = Int(Date().timeIntervalSince(start) * 1000.0)
        return SnapshotResult(html: html, text: text, finalURL: url, loadMs: elapsed, network: nil, pageStatus: nil, pageContentType: nil, adminNetwork: nil)
    }
}

public extension BrowserEngine {
    func snapshot(for url: String, wait: APIModels.WaitPolicy?, capture: CaptureOptions?) async throws -> SnapshotResult {
        let r = try await snapshotHTML(for: url)
        return SnapshotResult(html: r.html, text: r.text, finalURL: url, loadMs: nil, network: nil, pageStatus: nil, pageContentType: nil, adminNetwork: nil)
    }
}

public struct CaptureOptions: Sendable {
    public let allowedMIMEs: Set<String>?
    public let maxBodies: Int?
    public let maxBodyBytes: Int?
    public let maxTotalBytes: Int?
    public init(allowedMIMEs: Set<String>? = nil, maxBodies: Int? = nil, maxBodyBytes: Int? = nil, maxTotalBytes: Int? = nil) {
        self.allowedMIMEs = allowedMIMEs
        self.maxBodies = maxBodies
        self.maxBodyBytes = maxBodyBytes
        self.maxTotalBytes = maxTotalBytes
    }
}

public struct AdminNetworkRequest: Codable, Sendable, Equatable {
    public let url: String
    public let type: String?
    public let status: Int?
    public let method: String?
    public let requestHeaders: [String: String]?
    public let responseHeaders: [String: String]?
}

// © 2025 Contexter alias Benedikt Eickhoff 🛡️ All rights reserved.
