import Foundation
import SQLite3

final class DatabaseManager {
    private var db: OpaquePointer?
    private let dbURL: URL

    init(databaseName: String) {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.dbURL = documents.appendingPathComponent(databaseName)
        openDatabase()
        createSchemaIfNeeded()
    }

    deinit {
        sqlite3_close(db)
    }

    func withConnection<T>(_ block: (OpaquePointer?) throws -> T) rethrows -> T {
        try block(db)
    }

    func clearAllTables() throws {
        let statements = [
            "DELETE FROM password_entries;",
            "DELETE FROM chat_messages;"
        ]
        try withConnection { db in
            for sql in statements {
                try execute(sql: sql, db: db)
            }
        }
    }

    private func openDatabase() {
        if sqlite3_open(dbURL.path, &db) != SQLITE_OK {
            fatalError("Unable to open database at \(dbURL.path)")
        }
    }

    private func createSchemaIfNeeded() {
        let createPasswordEntries = """
        CREATE TABLE IF NOT EXISTS password_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            record_uuid TEXT NOT NULL UNIQUE,
            platform TEXT NOT NULL,
            account TEXT NOT NULL,
            password TEXT NOT NULL,
            note TEXT NOT NULL,
            primary_tag TEXT NOT NULL,
            secondary_tag TEXT,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            sync_version INTEGER NOT NULL,
            is_deleted INTEGER NOT NULL DEFAULT 0,
            deleted_at REAL,
            updated_by_device TEXT NOT NULL,
            sync_state TEXT NOT NULL
        );
        """

        let createChatMessages = """
        CREATE TABLE IF NOT EXISTS chat_messages (
            id TEXT PRIMARY KEY,
            role TEXT NOT NULL,
            content TEXT NOT NULL,
            payload_type TEXT NOT NULL,
            created_at REAL NOT NULL
        );
        """

        do {
            try withConnection { db in
                try execute(sql: createPasswordEntries, db: db)
                try execute(sql: createChatMessages, db: db)
            }
        } catch {
            fatalError("Unable to create schema: \(error)")
        }
    }

    private func execute(sql: String, db: OpaquePointer?) throws {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            throw SQLiteError.prepare(message: String(cString: sqlite3_errmsg(db)))
        }
        if sqlite3_step(statement) != SQLITE_DONE {
            throw SQLiteError.step(message: String(cString: sqlite3_errmsg(db)))
        }
    }
}

enum SQLiteError: Error, LocalizedError {
    case prepare(message: String)
    case bind(message: String)
    case step(message: String)

    var errorDescription: String? {
        switch self {
        case let .prepare(message): return "Prepare failed: \(message)"
        case let .bind(message): return "Bind failed: \(message)"
        case let .step(message): return "Step failed: \(message)"
        }
    }
}
