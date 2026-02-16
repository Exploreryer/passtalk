import Foundation

final class ExportService: ExportServiceProtocol {
    private let repository: PasswordRepositoryProtocol

    init(repository: PasswordRepositoryProtocol) {
        self.repository = repository
    }

    func exportEntries(format: ExportFormat) throws -> Data {
        let entries = try repository.queryEntries(includeDeleted: false)
        switch format {
        case .csv:
            return try CSVMapper.export(entries: entries)
        case .json:
            return try JSONMapper.export(entries: entries)
        }
    }
}
