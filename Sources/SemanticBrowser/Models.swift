import Foundation

public struct PageDoc: Codable, Sendable, Equatable {
    public let id: String
    public let url: String
    public let host: String
    public let status: Int?
    public let contentType: String?
    public let lang: String?
    public let title: String?
    public let textSize: Int?
    public let fetchedAt: Int?
    public let labels: [String]?
    public init(id: String, url: String, host: String, status: Int? = nil, contentType: String? = nil, lang: String? = nil, title: String? = nil, textSize: Int? = nil, fetchedAt: Int? = nil, labels: [String]? = nil) {
        self.id = id; self.url = url; self.host = host; self.status = status; self.contentType = contentType; self.lang = lang; self.title = title; self.textSize = textSize; self.fetchedAt = fetchedAt; self.labels = labels
    }
}

public struct SegmentDoc: Codable, Sendable, Equatable {
    public let id: String
    public let pageId: String
    public let kind: String
    public let text: String
    public let pathHint: String?
    public let offsetStart: Int?
    public let offsetEnd: Int?
    public let entities: [String]?
    public init(id: String, pageId: String, kind: String, text: String, pathHint: String? = nil, offsetStart: Int? = nil, offsetEnd: Int? = nil, entities: [String]? = nil) {
        self.id = id; self.pageId = pageId; self.kind = kind; self.text = text; self.pathHint = pathHint; self.offsetStart = offsetStart; self.offsetEnd = offsetEnd; self.entities = entities
    }
}

public struct EntityDoc: Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let type: String
    public let pageCount: Int?
    public let mentions: Int?
    public init(id: String, name: String, type: String, pageCount: Int? = nil, mentions: Int? = nil) {
        self.id = id; self.name = name; self.type = type; self.pageCount = pageCount; self.mentions = mentions
    }
}

// © 2025 Contexter alias Benedikt Eickhoff 🛡️ All rights reserved.

