import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class SQLitePasswordRepository: PasswordRepositoryProtocol {
    private let database: DatabaseManager
    private let deviceIDProvider: DeviceIDProvider

    init(database: DatabaseManager, deviceIDProvider: DeviceIDProvider) {
        self.database = database
        self.deviceIDProvider = deviceIDProvider
    }

    @discardableResult
    func createEntry(_ patch: EntryPatch) throws -> String {
        let now = Date().timeIntervalSince1970
        let recordUUID = UUID().uuidString

        let sql = """
        INSERT INTO password_entries (
            record_uuid, platform, account, password, note,
            primary_tag, secondary_tag, created_at, updated_at,
            sync_version, is_deleted, deleted_at, updated_by_device, sync_state
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        try database.withConnection { db in
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw SQLiteError.prepare(message: String(cString: sqlite3_errmsg(db)))
            }

            try bindText(recordUUID, at: 1, statement: statement, db: db)
            try bindText(patch.platform, at: 2, statement: statement, db: db)
            try bindText(patch.account, at: 3, statement: statement, db: db)
            try bindText(patch.password, at: 4, statement: statement, db: db)
            try bindText(patch.note, at: 5, statement: statement, db: db)
            try bindText(patch.primaryTag.rawValue, at: 6, statement: statement, db: db)
            if let secondary = patch.secondaryTag {
                try bindText(secondary.rawValue, at: 7, statement: statement, db: db)
            } else {
                sqlite3_bind_null(statement, 7)
            }
            sqlite3_bind_double(statement, 8, now)
            sqlite3_bind_double(statement, 9, now)
            sqlite3_bind_int(statement, 10, 1)
            sqlite3_bind_int(statement, 11, 0)
            sqlite3_bind_null(statement, 12)
            try bindText(deviceIDProvider.deviceID, at: 13, statement: statement, db: db)
            try bindText(SyncState.localOnly.rawValue, at: 14, statement: statement, db: db)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw SQLiteError.step(message: String(cString: sqlite3_errmsg(db)))
            }
        }

        return recordUUID
    }

    func updateEntry(recordUUID: String, patch: EntryPatch) throws {
        let sql = """
        UPDATE password_entries
        SET platform = ?,
            account = ?,
            password = ?,
            note = ?,
            primary_tag = ?,
            secondary_tag = ?,
            updated_at = ?,
            sync_version = sync_version + 1,
            updated_by_device = ?,
            sync_state = ?
        WHERE record_uuid = ?;
        """

        try database.withConnection { db in
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw SQLiteError.prepare(message: String(cString: sqlite3_errmsg(db)))
            }

            try bindText(patch.platform, at: 1, statement: statement, db: db)
            try bindText(patch.account, at: 2, statement: statement, db: db)
            try bindText(patch.password, at: 3, statement: statement, db: db)
            try bindText(patch.note, at: 4, statement: statement, db: db)
            try bindText(patch.primaryTag.rawValue, at: 5, statement: statement, db: db)

            if let secondary = patch.secondaryTag {
                try bindText(secondary.rawValue, at: 6, statement: statement, db: db)
            } else {
                sqlite3_bind_null(statement, 6)
            }

            sqlite3_bind_double(statement, 7, Date().timeIntervalSince1970)
            try bindText(deviceIDProvider.deviceID, at: 8, statement: statement, db: db)
            try bindText(SyncState.pendingUpload.rawValue, at: 9, statement: statement, db: db)
            try bindText(recordUUID, at: 10, statement: statement, db: db)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw SQLiteError.step(message: String(cString: sqlite3_errmsg(db)))
            }
        }
    }

    func deleteEntry(recordUUID: String) throws {
        let sql = """
        UPDATE password_entries
        SET is_deleted = 1,
            deleted_at = ?,
            updated_at = ?,
            sync_version = sync_version + 1,
            updated_by_device = ?,
            sync_state = ?
        WHERE record_uuid = ?;
        """

        let now = Date().timeIntervalSince1970
        try database.withConnection { db in
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw SQLiteError.prepare(message: String(cString: sqlite3_errmsg(db)))
            }

            sqlite3_bind_double(statement, 1, now)
            sqlite3_bind_double(statement, 2, now)
            try bindText(deviceIDProvider.deviceID, at: 3, statement: statement, db: db)
            try bindText(SyncState.pendingUpload.rawValue, at: 4, statement: statement, db: db)
            try bindText(recordUUID, at: 5, statement: statement, db: db)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw SQLiteError.step(message: String(cString: sqlite3_errmsg(db)))
            }
        }
    }

    func queryEntries(includeDeleted: Bool = false) throws -> [PasswordEntry] {
        let sql = includeDeleted
            ? "SELECT * FROM password_entries ORDER BY updated_at DESC;"
            : "SELECT * FROM password_entries WHERE is_deleted = 0 ORDER BY updated_at DESC;"

        return try fetchEntries(sql: sql, binds: nil)
    }

    func searchEntries(keyword: String, selectedTag: PresetTag?) throws -> [PasswordEntry] {
        var clauses = ["is_deleted = 0"]
        var values: [String] = []

        if !keyword.isEmpty {
            clauses.append("(platform LIKE ? OR account LIKE ? OR note LIKE ? OR primary_tag LIKE ? OR secondary_tag LIKE ?)")
            let fuzzy = "%\(keyword)%"
            values.append(contentsOf: [fuzzy, fuzzy, fuzzy, fuzzy, fuzzy])
        }

        if let tag = selectedTag {
            clauses.append("(primary_tag = ? OR secondary_tag = ?)")
            values.append(tag.rawValue)
            values.append(tag.rawValue)
        }

        let whereClause = clauses.joined(separator: " AND ")
        let sql = "SELECT * FROM password_entries WHERE \(whereClause) ORDER BY updated_at DESC;"
        return try fetchEntries(sql: sql, binds: values)
    }

    func fetchEntry(recordUUID: String) throws -> PasswordEntry? {
        let sql = "SELECT * FROM password_entries WHERE record_uuid = ? LIMIT 1;"
        return try fetchEntries(sql: sql, binds: [recordUUID]).first
    }

    private func fetchEntries(sql: String, binds: [String]?) throws -> [PasswordEntry] {
        try database.withConnection { db in
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }

            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw SQLiteError.prepare(message: String(cString: sqlite3_errmsg(db)))
            }

            if let binds {
                for (index, value) in binds.enumerated() {
                    try bindText(value, at: Int32(index + 1), statement: statement, db: db)
                }
            }

            var rows: [PasswordEntry] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                rows.append(try makeEntry(statement: statement))
            }
            return rows
        }
    }

    private func makeEntry(statement: OpaquePointer?) throws -> PasswordEntry {
        let id = sqlite3_column_int64(statement, 0)
        let recordUUID = columnString(statement, index: 1)
        let platform = columnString(statement, index: 2)
        let account = columnString(statement, index: 3)
        let password = columnString(statement, index: 4)
        let note = columnString(statement, index: 5)
        let primaryTagRaw = columnString(statement, index: 6)
        let secondaryTagRaw = columnNullableString(statement, index: 7)
        let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 8))
        let updatedAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 9))
        let syncVersion = Int(sqlite3_column_int(statement, 10))
        let isDeleted = sqlite3_column_int(statement, 11) == 1
        let deletedAt: Date?
        if sqlite3_column_type(statement, 12) == SQLITE_NULL {
            deletedAt = nil
        } else {
            deletedAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 12))
        }
        let updatedByDevice = columnString(statement, index: 13)
        let syncStateRaw = columnString(statement, index: 14)

        guard let primaryTag = PresetTag(rawValue: primaryTagRaw) else {
            throw SQLiteError.step(message: "Invalid primary tag")
        }

        let secondaryTag = secondaryTagRaw.flatMap { PresetTag(rawValue: $0) }
        let syncState = SyncState(rawValue: syncStateRaw) ?? .localOnly

        return PasswordEntry(
            id: id,
            recordUUID: recordUUID,
            platform: platform,
            account: account,
            password: password,
            note: note,
            primaryTag: primaryTag,
            secondaryTag: secondaryTag,
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncVersion: syncVersion,
            isDeleted: isDeleted,
            deletedAt: deletedAt,
            updatedByDevice: updatedByDevice,
            syncState: syncState
        )
    }

    private func bindText(_ value: String, at index: Int32, statement: OpaquePointer?, db: OpaquePointer?) throws {
        guard sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT) == SQLITE_OK else {
            throw SQLiteError.bind(message: String(cString: sqlite3_errmsg(db)))
        }
    }

    private func columnString(_ statement: OpaquePointer?, index: Int32) -> String {
        String(cString: sqlite3_column_text(statement, index))
    }

    private func columnNullableString(_ statement: OpaquePointer?, index: Int32) -> String? {
        guard let cString = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: cString)
    }
}
