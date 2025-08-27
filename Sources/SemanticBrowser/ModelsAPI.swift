import Foundation

// Minimal API models aligned to openapi/v1/semantic-browser.yml
public enum APIModels {
    // MARK: - Common
    public struct WaitPolicy: Codable, Sendable {
        public let strategy: String?
        public let networkIdleMs: Int?
        public let maxWaitMs: Int?
        public init(strategy: String? = nil, networkIdleMs: Int? = nil, maxWaitMs: Int? = nil) {
            self.strategy = strategy; self.networkIdleMs = networkIdleMs; self.maxWaitMs = maxWaitMs
        }
    }

    // MARK: - Snapshot
    public struct SnapshotRequest: Codable, Sendable {
        public let url: String
        public let wait: WaitPolicy
        public let storeArtifacts: Bool?
    }

    public struct SnapshotResponse: Codable, Sendable {
        public let snapshot: Snapshot
    }

    public struct Snapshot: Codable, Sendable {
        public struct Page: Codable, Sendable {
            public let uri: String
            public let finalUrl: String?
            public let fetchedAt: String
            public let status: Int
            public let contentType: String
            public let navigation: Navigation?
            public struct Navigation: Codable, Sendable { public let ttfbMs: Int?; public let loadMs: Int? }
        }
        public struct Rendered: Codable, Sendable {
            public let html: String
            public let text: String
            public let meta: [String: String]?
        }
        public struct Network: Codable, Sendable {
            public struct Request: Codable, Sendable {
                public let url: String
                public let type: String?
                public let status: Int?
                public let body: String?
            }
            public let requests: [Request]?
        }
        public let snapshotId: String
        public let page: Page
        public let rendered: Rendered
        public let network: Network?
        public let diagnostics: [String]?
    }

    // MARK: - Analyze / Analysis
    public struct AnalyzeRequest: Codable, Sendable {
        public struct SnapshotRef: Codable, Sendable { public let snapshotId: String }
        public let snapshot: Snapshot?
        public let snapshotRef: SnapshotRef?
        public let mode: String
    }

    public struct Analysis: Codable, Sendable {
        public struct Envelope: Codable, Sendable {
            public struct Source: Codable, Sendable { public let uri: String?; public let fetchedAt: String? }
            public let id: String
            public let source: Source?
            public let contentType: String?
            public let language: String?
            public let bytes: Int?
            public let diagnostics: [String]?
        }
        public struct Table: Codable, Sendable { public let caption: String?; public let columns: [String]?; public let rows: [[String]] }
        public struct Block: Codable, Sendable { public let id: String; public let kind: String; public let level: Int?; public let text: String; public let span: [Int]?; public let table: Table? }
        public struct Entity: Codable, Sendable { public let id: String; public let name: String; public let type: String; public let mentions: [Mention]?; public struct Mention: Codable, Sendable { public let block: String?; public let span: [Int]? } }
        public struct Claim: Codable, Sendable { public let id: String; public let text: String; public let stance: String?; public let hedge: String?; public let evidence: [Evidence]?; public struct Evidence: Codable, Sendable { public let block: String?; public let span: [Int]?; public let tableCell: [Int]? } }
        public struct Semantics: Codable, Sendable { public let outline: [OutlineItem]?; public let entities: [Entity]?; public let claims: [Claim]?; public let relations: [Relation]?; public struct OutlineItem: Codable, Sendable { public let block: String?; public let level: Int? }; public struct Relation: Codable, Sendable { public let type: String?; public let from: String?; public let to: String? } }
        public struct Summaries: Codable, Sendable { public let abstract: String?; public let keyPoints: [String]?; public let tl__dr: String?; enum CodingKeys: String, CodingKey { case abstract, keyPoints; case tl__dr = "tl;dr" } }
        public struct Provenance: Codable, Sendable { public let pipeline: String?; public let model: String? }

        public let envelope: Envelope
        public let blocks: [Block]
        public let semantics: Semantics?
        public let summaries: Summaries
        public let provenance: Provenance
    }

    // MARK: - Browse
    public struct BrowseRequest: Codable, Sendable {
        public struct IndexOptions: Codable, Sendable { public let enabled: Bool? }
        public let url: String
        public let wait: WaitPolicy
        public let mode: String
        public let index: IndexOptions?
        public let storeArtifacts: Bool?
        public let labels: [String]?
    }

    public struct BrowseResponse: Codable, Sendable {
        public let snapshot: Snapshot
        public let analysis: Analysis?
        public let index: IndexResult?
    }

    // MARK: - Index
    public struct IndexRequest: Codable, Sendable { public let analysis: Analysis; public struct Options: Codable, Sendable { public let enabled: Bool? }; public let options: Options? }
    public struct IndexResult: Codable, Sendable { public let pagesUpserted: Int; public let segmentsUpserted: Int; public let entitiesUpserted: Int; public let tablesUpserted: Int }
}

// Helpers
extension Date {
    var iso8601String: String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fmt.string(from: self)
    }
}
