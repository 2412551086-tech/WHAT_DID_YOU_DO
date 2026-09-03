import Foundation

struct LocalDraftFamily: Codable, Equatable, Identifiable {
    static let currentSchemaVersion = 1

    let id: UUID
    var schemaVersion: Int
    var createdAt: Date
    var updatedAt: Date
    var name: String
    var selectedChores: [LocalDraftChore]
    var records: [LocalDraftChoreRecord]
    var claimState: LocalDraftClaimState

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        name: String = "我的家庭",
        selectedChores: [LocalDraftChore] = [],
        records: [LocalDraftChoreRecord] = [],
        claimState: LocalDraftClaimState = .local
    ) {
        self.id = id
        schemaVersion = Self.currentSchemaVersion
        self.createdAt = createdAt
        updatedAt = createdAt
        self.name = name
        self.selectedChores = selectedChores
        self.records = records
        self.claimState = claimState
    }
}

enum LocalDraftClaimState: String, Codable, Equatable {
    case local
    case claiming
    case claimed
}

struct LocalDraftChore: Codable, Equatable, Identifiable {
    enum Source: String, Codable {
        case catalog
        case custom
    }

    let id: String
    let source: Source
    let catalogKey: String?
    var name: String
    var category: String
    var minutes: Int
    var points: Int
    var icon: String
    var themeKey: String
    var difficultyMultiplier: Double
    var customSlot: Int?

    init(chore: ChoreItem) {
        id = chore.id
        source = chore.isCustom ? .custom : .catalog
        catalogKey = chore.catalogKey ?? Self.fallbackCatalogKey(for: chore.id)
        name = chore.name
        category = chore.category
        minutes = chore.minutes
        points = chore.points
        icon = chore.icon
        themeKey = chore.themeKey
        difficultyMultiplier = chore.difficultyMultiplier
        customSlot = chore.customSlot
    }

    private static func fallbackCatalogKey(for id: String) -> String {
        switch id {
        case "mock-chore-cook": "core-cook-prepare"
        case "mock-chore-dishes": "core-dishes-cleanup"
        case "mock-chore-laundry": "core-laundry"
        case "mock-chore-put-away-clothes": "core-fold-clothes"
        case "mock-chore-vacuum": "core-sweep-vacuum"
        case "mock-chore-mop": "core-mop-floor"
        case "mock-chore-organize": "core-organize-storage"
        case "mock-chore-bathroom": "core-bathroom-clean"
        case "mock-chore-trash": "core-trash-recycling"
        case "mock-chore-shopping": "core-shopping-supplies"
        default: id
        }
    }
}

struct LocalDraftChoreRecord: Codable, Equatable, Identifiable {
    let id: UUID
    let choreID: String
    let choreName: String
    let category: String
    let standardMinutes: Int
    let defaultPoints: Int
    let icon: String
    let actualMinutes: Int
    let points: Int
    let pointsMultiplier: Double?
    let note: String
    let occurredAt: Date
}

protocol LocalWorkspaceStoreProtocol {
    func load() throws -> LocalDraftFamily?
    func save(_ draft: LocalDraftFamily) throws
    func delete() throws
}

final class FileLocalWorkspaceStore: LocalWorkspaceStoreProtocol {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let directory = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0].appendingPathComponent("WhatDidYouDo", isDirectory: true)
            self.fileURL = directory.appendingPathComponent("local-workspace-v1.json")
        }

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() throws -> LocalDraftFamily? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        let draft = try decoder.decode(LocalDraftFamily.self, from: data)
        guard draft.schemaVersion == LocalDraftFamily.currentSchemaVersion else {
            throw LocalWorkspaceStoreError.unsupportedSchema
        }
        return draft
    }

    func save(_ draft: LocalDraftFamily) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try encoder.encode(draft).write(to: fileURL, options: [.atomic, .completeFileProtection])
    }

    func delete() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}

enum LocalWorkspaceStoreError: LocalizedError {
    case unsupportedSchema

    var errorDescription: String? {
        "本机体验数据版本过旧，请更新 App 后重试。"
    }
}
