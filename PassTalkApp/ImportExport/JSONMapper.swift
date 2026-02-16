import Foundation

enum JSONMapper {
    static func mapPassTalk(data: Data) throws -> [EntryPatch] {
        let decoder = JSONDecoder()
        let payload = try decoder.decode([PassTalkJSONEntry].self, from: data)
        return payload.map {
            EntryPatch(
                platform: $0.platform,
                account: $0.account,
                password: $0.password,
                note: $0.note ?? "",
                primaryTag: PresetTag(rawValue: $0.primaryTag ?? "") ?? .other,
                secondaryTag: PresetTag(rawValue: $0.secondaryTag ?? "")
            )
        }
    }

    static func mapBitwarden(data: Data) throws -> [EntryPatch] {
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let items = root?["items"] as? [[String: Any]] ?? []
        return items.compactMap { item in
            guard let login = item["login"] as? [String: Any] else { return nil }
            let platform = (item["name"] as? String) ?? ""
            let account = (login["username"] as? String) ?? ""
            let password = (login["password"] as? String) ?? ""
            let note = (item["notes"] as? String) ?? ""
            return EntryPatch(platform: platform, account: account, password: password, note: note, primaryTag: .other, secondaryTag: nil)
        }
    }

    static func mapOnePassword(data: Data) throws -> [EntryPatch] {
        let root = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
        return root.compactMap { item in
            let platform = (item["title"] as? String) ?? ""
            let fields = item["fields"] as? [[String: Any]] ?? []
            let account = fields.first(where: { ($0["designation"] as? String) == "username" })?["value"] as? String ?? ""
            let password = fields.first(where: { ($0["designation"] as? String) == "password" })?["value"] as? String ?? ""
            let note = (item["notesPlain"] as? String) ?? ""
            return EntryPatch(platform: platform, account: account, password: password, note: note, primaryTag: .other, secondaryTag: nil)
        }
    }

    static func export(entries: [PasswordEntry]) throws -> Data {
        let payload = entries.map {
            PassTalkJSONEntry(
                platform: $0.platform,
                account: $0.account,
                password: $0.password,
                note: $0.note,
                primaryTag: $0.primaryTag.rawValue,
                secondaryTag: $0.secondaryTag?.rawValue
            )
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }
}

private struct PassTalkJSONEntry: Codable {
    let platform: String
    let account: String
    let password: String
    let note: String?
    let primaryTag: String?
    let secondaryTag: String?
}

enum ImportError: Error {
    case invalidEncoding
    case unsupportedFormat
}
