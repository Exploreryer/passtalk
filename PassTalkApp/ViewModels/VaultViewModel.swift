import Foundation

@MainActor
final class VaultViewModel: ObservableObject {
    @Published var entries: [PasswordEntry] = []
    @Published var keyword: String = ""
    @Published var selectedTag: PresetTag?
    @Published var isPresentingEditor = false
    @Published var editingEntry: PasswordEntry?
    @Published var errorMessage: String?

    private let repository: PasswordRepositoryProtocol

    init(repository: PasswordRepositoryProtocol) {
        self.repository = repository
    }

    func reload() {
        do {
            entries = try repository.searchEntries(keyword: keyword, selectedTag: selectedTag)
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
    }

    func delete(recordUUID: String) {
        do {
            try repository.deleteEntry(recordUUID: recordUUID)
            reload()
        } catch {
            errorMessage = "删除失败：\(error.localizedDescription)"
        }
    }

    func save(platform: String, account: String, password: String, note: String, primaryTag: PresetTag, secondaryTag: PresetTag?) {
        let patch = EntryPatch(platform: platform, account: account, password: password, note: note, primaryTag: primaryTag, secondaryTag: secondaryTag)

        do {
            if let editingEntry {
                try repository.updateEntry(recordUUID: editingEntry.recordUUID, patch: patch)
            } else {
                _ = try repository.createEntry(patch)
            }
            editingEntry = nil
            isPresentingEditor = false
            reload()
        } catch {
            errorMessage = "保存失败：\(error.localizedDescription)"
        }
    }
}
