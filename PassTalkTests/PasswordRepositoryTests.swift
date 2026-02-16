import XCTest
@testable import PassTalkApp

final class PasswordRepositoryTests: XCTestCase {
    func testCreateUpdateDeleteSyncFields() throws {
        let dbName = "test-\(UUID().uuidString).sqlite"
        let database = DatabaseManager(databaseName: dbName)
        let repository = SQLitePasswordRepository(database: database, deviceIDProvider: DeviceIDProvider.shared)

        let uuid = try repository.createEntry(
            EntryPatch(
                platform: "GitHub",
                account: "alex@github.com",
                password: "Gh!2024x",
                note: "",
                primaryTag: .devtools,
                secondaryTag: nil
            )
        )

        var row = try XCTUnwrap(repository.fetchEntry(recordUUID: uuid))
        XCTAssertEqual(row.syncVersion, 1)
        XCTAssertEqual(row.syncState, .localOnly)
        XCTAssertFalse(row.isDeleted)

        try repository.updateEntry(
            recordUUID: uuid,
            patch: EntryPatch(
                platform: "GitHub",
                account: "alex@github.com",
                password: "Gh!2024x-NEW",
                note: "updated",
                primaryTag: .devtools,
                secondaryTag: .work
            )
        )

        row = try XCTUnwrap(repository.fetchEntry(recordUUID: uuid))
        XCTAssertEqual(row.syncVersion, 2)
        XCTAssertEqual(row.syncState, .pendingUpload)

        try repository.deleteEntry(recordUUID: uuid)
        row = try XCTUnwrap(repository.fetchEntry(recordUUID: uuid))
        XCTAssertTrue(row.isDeleted)

        let visibleRows = try repository.queryEntries(includeDeleted: false)
        XCTAssertEqual(visibleRows.count, 0)

        let allRows = try repository.queryEntries(includeDeleted: true)
        XCTAssertEqual(allRows.count, 1)
    }

    func testCSVImportSupportsQuotedCommaAndNewline() throws {
        let csv = "platform,account,password,note,primary_tag\n" +
            "GitHub,alex@github.com,Gh!2024x,\"line1, with comma\nline2 with \"\"quote\"\"\",devtools\n"
        let patches = try CSVMapper.mapGenericCSV(data: Data(csv.utf8))
        XCTAssertEqual(patches.count, 1)

        let first = try XCTUnwrap(patches.first)
        XCTAssertEqual(first.platform, "GitHub")
        XCTAssertEqual(first.account, "alex@github.com")
        XCTAssertEqual(first.password, "Gh!2024x")
        XCTAssertEqual(first.note, "line1, with comma\nline2 with \"quote\"")
        XCTAssertEqual(first.primaryTag, .devtools)
    }
}
