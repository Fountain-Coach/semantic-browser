import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

public struct ArtifactRef: Sendable, Codable, Equatable {
    public let id: String
    public let sha256: String
    public let size: Int
    public let kind: String
    public let mime: String
    public let ext: String
    public let refPath: String
    public let createdAt: Date
}

public protocol ArtifactStore: Sendable {
    func put(kind: String, ext: String, mime: String, data: Data, ttlDays: Int) throws -> ArtifactRef
    func get(refPath: String) throws -> (data: Data, mime: String)?
    func delete(refPath: String) throws
    func gc(now: Date) throws -> Int
}

public final class FSArtifactStore: ArtifactStore, @unchecked Sendable {
    let root: URL
    let budgetBytes: Int64?
    public init(rootPath: String, budgetBytes: Int64? = nil) throws {
        self.root = URL(fileURLWithPath: rootPath)
        self.budgetBytes = budgetBytes
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    public func put(kind: String, ext: String, mime: String, data: Data, ttlDays: Int) throws -> ArtifactRef {
        let sha = sha256Hex(data)
        let now = Date()
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: now)
        let y = String(format: "%04d", comps.year ?? 1970)
        let m = String(format: "%02d", comps.month ?? 1)
        let d = String(format: "%02d", comps.day ?? 1)
        let dir = root.appendingPathComponent(kind).appendingPathComponent(y).appendingPathComponent(m).appendingPathComponent(d)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let filename = "\(sha).\(ext)"
        let fileURL = dir.appendingPathComponent(filename)
        try data.write(to: fileURL, options: .atomic)
        // write sidecar meta for TTL and mime
        let meta: [String: Any] = ["mime": mime, "ttlDays": ttlDays, "createdAt": now.timeIntervalSince1970]
        let metaURL = dir.appendingPathComponent("\(sha).meta.json")
        let metaData = try JSONSerialization.data(withJSONObject: meta)
        try metaData.write(to: metaURL, options: .atomic)
        return ArtifactRef(id: UUID().uuidString, sha256: sha, size: data.count, kind: kind, mime: mime, ext: ext, refPath: fileURL.path, createdAt: now)
    }

    public func get(refPath: String) throws -> (data: Data, mime: String)? {
        let url = URL(fileURLWithPath: refPath)
        let data = try Data(contentsOf: url)
        let metaURL = url.deletingPathExtension().appendingPathExtension("meta.json")
        var mime = "application/octet-stream"
        if let md = try? Data(contentsOf: metaURL), let obj = try? JSONSerialization.jsonObject(with: md) as? [String: Any], let m = obj["mime"] as? String { mime = m }
        return (data, mime)
    }

    public func delete(refPath: String) throws {
        try FileManager.default.removeItem(atPath: refPath)
        let metaPath = (refPath as NSString).deletingPathExtension + ".meta.json"
        _ = try? FileManager.default.removeItem(atPath: metaPath)
    }

    public func gc(now: Date) throws -> Int {
        var removed = 0
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return 0 }
        for case let url as URL in enumerator {
            if url.pathExtension == "json" && url.lastPathComponent.hasSuffix("meta.json") {
                if let md = try? Data(contentsOf: url), let obj = try? JSONSerialization.jsonObject(with: md) as? [String: Any], let created = obj["createdAt"] as? Double, let ttl = obj["ttlDays"] as? Int {
                    let expiry = Date(timeIntervalSince1970: created).addingTimeInterval(TimeInterval(ttl * 86_400))
                    if now >= expiry {
                        _ = url.deletingPathExtension().deletingPathExtension().appendingPathExtension("bin")
                        _ = (url.deletingPathExtension().deletingPathExtension().path)
                        // remove corresponding data file (unknown ext), best-effort: remove any file beginning with sha.* in same dir
                        let sha = url.deletingPathExtension().deletingPathExtension().lastPathComponent
                        if let dirEnum = FileManager.default.enumerator(at: url.deletingLastPathComponent(), includingPropertiesForKeys: nil) {
                            for case let f as URL in dirEnum {
                                if f.lastPathComponent.hasPrefix(sha + ".") { _ = try? FileManager.default.removeItem(at: f); removed += 1 }
                            }
                        }
                        _ = try? FileManager.default.removeItem(at: url)
                    }
                }
            }
        }
        return removed
    }

    private func sha256Hex(_ data: Data) -> String {
        #if canImport(CryptoKit)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
        #else
        // Fallback: simple hash (not cryptographic) if CryptoKit unavailable
        return String(data.hashValue, radix: 16)
        #endif
    }
}

#if canImport(Typesense)
import Typesense

public final class TypesenseArtifacts: @unchecked Sendable {
    let client: Client
    public init(nodes: [String], apiKey: String, debug: Bool = false) {
        let tsNodes = nodes.map { Node(url: $0) }
        let config = Configuration(nodes: tsNodes, apiKey: apiKey, logger: Logger(debugMode: debug))
        self.client = Client(config: config)
        Task { try? await self.ensureCollection() }
    }
    private func ensureCollection() async throws {
        let fields = [
            Field(name: "id", type: "string"),
            Field(name: "pageId", type: "string"),
            Field(name: "analysisId", type: "string"),
            Field(name: "kind", type: "string"),
            Field(name: "mime", type: "string"),
            Field(name: "size", type: "int64"),
            Field(name: "sha256", type: "string"),
            Field(name: "labels", type: "string[]"),
            Field(name: "host", type: "string"),
            Field(name: "lang", type: "string"),
            Field(name: "createdAt", type: "int64"),
            Field(name: "ttlAt", type: "int64", _optional: true),
            Field(name: "inlineBody", type: "string", _optional: true),
            Field(name: "blobRef", type: "string", _optional: true)
        ]
        _ = try? await client.collections.create(schema: CollectionSchema(name: "artifacts", fields: fields, defaultSortingField: nil))
    }
    public struct ArtifactDoc: Codable {
        public let id: String
        public let pageId: String?
        public let analysisId: String?
        public let kind: String
        public let mime: String
        public let size: Int
        public let sha256: String
        public let labels: [String]?
        public let host: String?
        public let lang: String?
        public let createdAt: Int64
        public let ttlAt: Int64?
        public let inlineBody: String?
        public let blobRef: String?
    }
    public func upsert(_ doc: ArtifactDoc) {
        if let data = try? JSONEncoder().encode(doc) {
            Task { _ = try? await client.collection(name: "artifacts").documents().upsert(document: data) }
        }
    }

    public func search(pageId: String? = nil, analysisId: String? = nil, kind: String? = nil, limit: Int = 50) async -> [ArtifactDoc] {
        return []
    }
}
#endif
