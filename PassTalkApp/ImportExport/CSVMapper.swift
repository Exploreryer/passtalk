import Foundation

enum CSVMapper {
    static func mapGenericCSV(data: Data) throws -> [EntryPatch] {
        guard let string = String(data: data, encoding: .utf8) else {
            throw ImportError.invalidEncoding
        }

        let rows = parseCSVRows(from: string)
        guard let header = rows.first else { return [] }

        let columns = header.enumerated().map { index, value in
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return (index == 0) ? normalized.replacingOccurrences(of: "\u{feff}", with: "") : normalized
        }
        let indexMap = Dictionary(uniqueKeysWithValues: columns.enumerated().map { ($1, $0) })

        func value(_ parts: [String], _ keys: [String]) -> String {
            for key in keys {
                if let idx = indexMap[key], idx < parts.count {
                    return parts[idx].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            return ""
        }

        return rows.dropFirst().compactMap { parts in
            let platform = value(parts, ["platform", "name", "title"])
            let account = value(parts, ["account", "username", "login"])
            let password = value(parts, ["password", "pass"])
            let note = value(parts, ["note", "notes"])
            let tagRaw = value(parts, ["tag", "primary_tag"])
            if platform.isEmpty, account.isEmpty, password.isEmpty, note.isEmpty, tagRaw.isEmpty {
                return nil
            }
            let tag = PresetTag(rawValue: tagRaw) ?? .other
            return EntryPatch(platform: platform, account: account, password: password, note: note, primaryTag: tag, secondaryTag: nil)
        }
    }

    static func export(entries: [PasswordEntry]) throws -> Data {
        let header = "platform,account,password,note,primary_tag,secondary_tag,created_at,updated_at\n"
        let rows = entries.map { entry in
            [
                entry.platform,
                entry.account,
                entry.password,
                entry.note,
                entry.primaryTag.rawValue,
                entry.secondaryTag?.rawValue ?? "",
                String(entry.createdAt.timeIntervalSince1970),
                String(entry.updatedAt.timeIntervalSince1970)
            ].map(escape).joined(separator: ",")
        }.joined(separator: "\n")

        guard let data = (header + rows).data(using: .utf8) else {
            throw ImportError.invalidEncoding
        }
        return data
    }

    private static func escape(_ input: String) -> String {
        if input.contains(",") || input.contains("\"") || input.contains("\n") {
            return "\"" + input.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return input
    }

    private static func parseCSVRows(from text: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var isInsideQuotes = false

        var index = text.startIndex
        while index < text.endIndex {
            let char = text[index]

            if isInsideQuotes {
                if char == "\"" {
                    let nextIndex = text.index(after: index)
                    if nextIndex < text.endIndex, text[nextIndex] == "\"" {
                        currentField.append("\"")
                        index = nextIndex
                    } else {
                        isInsideQuotes = false
                    }
                } else {
                    currentField.append(char)
                }
            } else {
                switch char {
                case "\"":
                    isInsideQuotes = true
                case ",":
                    currentRow.append(currentField)
                    currentField = ""
                case "\n":
                    currentRow.append(currentField)
                    rows.append(currentRow)
                    currentRow = []
                    currentField = ""
                case "\r":
                    break
                default:
                    currentField.append(char)
                }
            }

            index = text.index(after: index)
        }

        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }

        return rows
    }
}
