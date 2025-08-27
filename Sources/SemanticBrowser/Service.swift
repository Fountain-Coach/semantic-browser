import Foundation

public actor SemanticMemoryService {
    public protocol Backend: Sendable {
        func upsert(page: PageDoc)
        func upsert(segment: SegmentDoc)
        func upsert(entity: EntityDoc)
        func searchPages(q: String?, host: String?, lang: String?, limit: Int, offset: Int) -> (Int, [PageDoc])
        func searchSegments(q: String?, kind: String?, entity: String?, limit: Int, offset: Int) -> (Int, [SegmentDoc])
        func searchEntities(q: String?, type: String?, limit: Int, offset: Int) -> (Int, [EntityDoc])
    }

    private var pages: [PageDoc] = []
    private var segments: [SegmentDoc] = []
    private var entities: [EntityDoc] = []
    private let backend: Backend?
    // Stored artifacts for snapshot/analyze/export
    public struct Snapshot: Codable, Sendable {
        public let id: String
        public let url: String
        public let renderedHTML: String
        public let renderedText: String
        public init(id: String, url: String, renderedHTML: String, renderedText: String) { self.id = id; self.url = url; self.renderedHTML = renderedHTML; self.renderedText = renderedText }
    }
    private var snapshots: [String: Snapshot] = [:] // key: snapshotId
    private var analyses: [String: FullAnalysis] = [:] // key: envelope.id
    private var analysisToSnapshot: [String: String] = [:]
    private var snapshotToAnalysis: [String: String] = [:]
    private var networks: [String: [AdminNetworkRequest]] = [:]
    private var artifactRefs: [String: [String: String]] = [:] // key: id (snapshotId or analysisId) -> kind -> refPath

    public init(backend: Backend? = nil) { self.backend = backend }

    // Seeding for tests or importers
    public func seed(pages: [PageDoc] = [], segments: [SegmentDoc] = [], entities: [EntityDoc] = []) {
        self.pages.append(contentsOf: pages)
        self.segments.append(contentsOf: segments)
        self.entities.append(contentsOf: entities)
    }

    public func queryPages(q: String?, host: String?, lang: String?, limit: Int, offset: Int) -> (total: Int, items: [PageDoc]) {
        if let backend { let (t, items) = backend.searchPages(q: q, host: host, lang: lang, limit: limit, offset: offset); return (t, items) }
        var list = pages
        if let host, !host.isEmpty { list = list.filter { $0.host == host } }
        if let lang, !lang.isEmpty { list = list.filter { $0.lang?.lowercased() == lang.lowercased() } }
        if let q, !q.isEmpty {
            let n = q.lowercased()
            list = list.filter { ($0.title ?? "").lowercased().contains(n) || ($0.url).lowercased().contains(n) }
        }
        let total = list.count
        let slice = Array(list.dropFirst(min(offset, total)).prefix(limit))
        return (total, slice)
    }

    public func querySegments(q: String?, kind: String?, entity: String?, limit: Int, offset: Int) -> (total: Int, items: [SegmentDoc]) {
        if let backend { let (t, items) = backend.searchSegments(q: q, kind: kind, entity: entity, limit: limit, offset: offset); return (t, items) }
        var list = segments
        if let kind, !kind.isEmpty { list = list.filter { $0.kind == kind } }
        if let entity, !entity.isEmpty { list = list.filter { ($0.entities ?? []).contains(entity) } }
        if let q, !q.isEmpty { let n = q.lowercased(); list = list.filter { $0.text.lowercased().contains(n) } }
        let total = list.count
        let slice = Array(list.dropFirst(min(offset, total)).prefix(limit))
        return (total, slice)
    }

    public func queryEntities(q: String?, type: String?, limit: Int, offset: Int) -> (total: Int, items: [EntityDoc]) {
        if let backend { let (t, items) = backend.searchEntities(q: q, type: type, limit: limit, offset: offset); return (t, items) }
        var list = entities
        if let type, !type.isEmpty { list = list.filter { $0.type == type } }
        if let q, !q.isEmpty { let n = q.lowercased(); list = list.filter { $0.name.lowercased().contains(n) } }
        let total = list.count
        let slice = Array(list.dropFirst(min(offset, total)).prefix(limit))
        return (total, slice)
    }

    // MARK: - Ingest (Index)
    public struct IndexRequest: Codable, Sendable {
        public let analysis: IngestAnalysis
        public init(analysis: IngestAnalysis) { self.analysis = analysis }
    }
    public struct IngestAnalysis: Codable, Sendable {
        public let page: PageDoc
        public let segments: [SegmentDoc]?
        public let entities: [EntityDoc]?
        public init(page: PageDoc, segments: [SegmentDoc]? = nil, entities: [EntityDoc]? = nil) {
            self.page = page; self.segments = segments; self.entities = entities
        }
    }
    public struct IndexResult: Codable, Sendable {
        public let pagesUpserted: Int
        public let segmentsUpserted: Int
        public let entitiesUpserted: Int
        public let tablesUpserted: Int
    }

    public func ingest(_ req: IndexRequest) -> IndexResult {
        var pUp = 0, sUp = 0, eUp = 0
        // Upsert page by id
        if let backend {
            backend.upsert(page: req.analysis.page)
        } else {
            if let idx = pages.firstIndex(where: { $0.id == req.analysis.page.id }) { pages[idx] = req.analysis.page } else { pages.append(req.analysis.page) }
        }
        pUp = 1
        if let segs = req.analysis.segments {
            for s in segs {
                if let backend { backend.upsert(segment: s) } else { if let i = segments.firstIndex(where: { $0.id == s.id }) { segments[i] = s } else { segments.append(s) } }
                sUp += 1
            }
        }
        if let ents = req.analysis.entities {
            for e in ents {
                if let backend { backend.upsert(entity: e) } else { if let i = entities.firstIndex(where: { $0.id == e.id }) { entities[i] = e } else { entities.append(e) } }
                eUp += 1
            }
        }
        return IndexResult(pagesUpserted: pUp, segmentsUpserted: sUp, entitiesUpserted: eUp, tablesUpserted: 0)
    }

    // MARK: - Full Analysis mapping (subset of OpenAPI)
    public struct FullAnalysis: Codable, Sendable {
        public struct Envelope: Codable, Sendable {
            public struct Source: Codable, Sendable { public let uri: String? }
            public let id: String
            public let source: Source?
            public let contentType: String?
            public let language: String?
        }
        public struct Table: Codable, Sendable { public let caption: String?; public let columns: [String]?; public let rows: [[String]] }
        public struct Block: Codable, Sendable {
            public let id: String
            public let kind: String
            public let text: String
            public let table: Table?
        }
        public struct Semantics: Codable, Sendable {
            public struct Entity: Codable, Sendable { public let id: String; public let name: String; public let type: String }
            public let entities: [Entity]?
        }
        public let envelope: Envelope
        public let blocks: [Block]
        public let semantics: Semantics?
    }

    public func ingest(full: FullAnalysis) -> IndexResult {
        let url = full.envelope.source?.uri ?? ""
        let host = URL(string: url)?.host ?? ""
        let title = full.blocks.first(where: { $0.kind == "heading" })?.text
        let textSize = full.blocks.reduce(0) { $0 + $1.text.count }
        let pageId = full.envelope.id
        let page = PageDoc(id: pageId, url: url, host: host, status: nil, contentType: full.envelope.contentType, lang: full.envelope.language, title: title, textSize: textSize, fetchedAt: nil, labels: nil)
        var segs: [SegmentDoc] = []
        for b in full.blocks { segs.append(SegmentDoc(id: b.id, pageId: pageId, kind: b.kind, text: b.text)) }
        var ents: [EntityDoc] = []
        if let es = full.semantics?.entities { ents = es.map { EntityDoc(id: $0.id, name: $0.name, type: $0.type) } }
        return ingest(IndexRequest(analysis: IngestAnalysis(page: page, segments: segs, entities: ents)))
    }

    // MARK: - Snapshot / Analyze artifact storage
    public func store(snapshot: Snapshot) { snapshots[snapshot.id] = snapshot }
    public func loadSnapshot(id: String) -> Snapshot? { snapshots[id] }
    public func store(analysis: FullAnalysis, forSnapshotId snapshotId: String? = nil) {
        analyses[analysis.envelope.id] = analysis
        if let sid = snapshotId {
            analysisToSnapshot[analysis.envelope.id] = sid
            snapshotToAnalysis[sid] = analysis.envelope.id
        }
    }
    public func loadAnalysis(id: String) -> FullAnalysis? { analyses[id] }
    public func resolveSnapshot(byPageId id: String) -> Snapshot? {
        if let s = snapshots[id] { return s }
        if let sid = analysisToSnapshot[id], let s = snapshots[sid] { return s }
        return nil
    }
    public func resolveAnalysis(byPageId id: String) -> FullAnalysis? {
        if let a = analyses[id] { return a }
        if let aid = snapshotToAnalysis[id], let a = analyses[aid] { return a }
        return nil
    }

    public func storeNetwork(snapshotId: String, requests: [AdminNetworkRequest]?) { if let r = requests { networks[snapshotId] = r } }
    public func loadNetwork(snapshotId: String) -> [AdminNetworkRequest]? { networks[snapshotId] }

    public func storeArtifactRef(ownerId: String, kind: String, refPath: String) {
        var m = artifactRefs[ownerId] ?? [:]
        m[kind] = refPath
        artifactRefs[ownerId] = m
    }
    public func loadArtifactRef(ownerId: String, kind: String) -> String? { artifactRefs[ownerId]?[kind] }
    public func getPage(id: String) -> PageDoc? {
        if let p = pages.first(where: { $0.id == id }) { return p }
        // Backend fallback: naive search and filter by id
        if let backend {
            let (total, list) = backend.searchPages(q: "*", host: nil, lang: nil, limit: 200, offset: 0)
            if total > 0 { return list.first(where: { $0.id == id }) }
        }
        return nil
    }
}

// © 2025 Contexter alias Benedikt Eickhoff 🛡️ All rights reserved.
