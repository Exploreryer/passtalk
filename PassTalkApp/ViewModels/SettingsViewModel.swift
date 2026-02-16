import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var apiKey: String = ""
    @Published var showClearAllConfirm: Bool = false
    @Published var toast: String?

    private let keychain: KeychainStore
    private let database: DatabaseManager

    init(keychain: KeychainStore, database: DatabaseManager) {
        self.keychain = keychain
        self.database = database
        do {
            apiKey = try keychain.get(OpenAIClient.apiKeyKey) ?? ""
        } catch {
            apiKey = ""
        }
    }

    func saveApiKey() {
        do {
            try keychain.set(apiKey, for: OpenAIClient.apiKeyKey)
            toast = "API Key 已保存"
        } catch {
            toast = "保存失败"
        }
    }

    func clearAllData() {
        do {
            try database.clearAllTables()
            toast = "数据已清空"
        } catch {
            toast = "清空失败"
        }
    }
}
