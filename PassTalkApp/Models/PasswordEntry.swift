import Foundation

struct PasswordEntry: Identifiable, Codable, Equatable {
    var id: Int64?
    var recordUUID: String
    var platform: String
    var account: String
    var password: String
    var note: String
    var primaryTag: PresetTag
    var secondaryTag: PresetTag?
    var createdAt: Date
    var updatedAt: Date

    // Sync-ready fields (V1 keeps local only)
    var syncVersion: Int
    var isDeleted: Bool
    var deletedAt: Date?
    var updatedByDevice: String
    var syncState: SyncState

    init(
        id: Int64? = nil,
        recordUUID: String = UUID().uuidString,
        platform: String,
        account: String,
        password: String,
        note: String = "",
        primaryTag: PresetTag,
        secondaryTag: PresetTag? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncVersion: Int = 1,
        isDeleted: Bool = false,
        deletedAt: Date? = nil,
        updatedByDevice: String,
        syncState: SyncState = .localOnly
    ) {
        self.id = id
        self.recordUUID = recordUUID
        self.platform = platform
        self.account = account
        self.password = password
        self.note = note
        self.primaryTag = primaryTag
        self.secondaryTag = secondaryTag
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncVersion = syncVersion
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
        self.updatedByDevice = updatedByDevice
        self.syncState = syncState
    }
}

struct EntryPatch {
    var platform: String
    var account: String
    var password: String
    var note: String
    var primaryTag: PresetTag
    var secondaryTag: PresetTag?
}
