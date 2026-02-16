import Foundation

final class ImportService: ImportServiceProtocol {
    private let repository: PasswordRepositoryProtocol

    init(repository: PasswordRepositoryProtocol) {
        self.repository = repository
    }

    func importEntries(from data: Data, format: ImportFormat) throws -> ImportReport {
        let patches: [EntryPatch]

        switch format {
        case .csv:
            patches = try CSVMapper.mapGenericCSV(data: data)
        case .bitwarden:
            patches = try JSONMapper.mapBitwarden(data: data)
        case .onePassword:
            patches = try JSONMapper.mapOnePassword(data: data)
        case .json:
            patches = try JSONMapper.mapPassTalk(data: data)
        }

        var imported = 0
        var skipped = 0

        for patch in patches {
            guard !patch.platform.isEmpty, !patch.account.isEmpty else {
                skipped += 1
                continue
            }
            _ = try repository.createEntry(patch)
            imported += 1
        }

        return ImportReport(importedCount: imported, skippedCount: skipped)
    }
}
