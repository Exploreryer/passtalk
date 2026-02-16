import Foundation

protocol PasswordRepositoryProtocol {
    @discardableResult
    func createEntry(_ patch: EntryPatch) throws -> String
    func updateEntry(recordUUID: String, patch: EntryPatch) throws
    func deleteEntry(recordUUID: String) throws
    func queryEntries(includeDeleted: Bool) throws -> [PasswordEntry]
    func searchEntries(keyword: String, selectedTag: PresetTag?) throws -> [PasswordEntry]
    func fetchEntry(recordUUID: String) throws -> PasswordEntry?
}
