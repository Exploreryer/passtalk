import Foundation

enum ImportFormat {
    case csv
    case json
    case bitwarden
    case onePassword
}

enum ExportFormat {
    case csv
    case json
}

struct ImportReport {
    let importedCount: Int
    let skippedCount: Int
}

protocol ImportServiceProtocol {
    func importEntries(from data: Data, format: ImportFormat) throws -> ImportReport
}

protocol ExportServiceProtocol {
    func exportEntries(format: ExportFormat) throws -> Data
}
