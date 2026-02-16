import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var endpoint: String = ""
    @Published var model: String = ""
    @Published var systemPrompt: String = ""
    @Published var apiKey: String = ""
    @Published var showClearAllConfirm: Bool = false
    @Published var toast: String?
    @Published var isTestingConnection: Bool = false
    @Published var testResultMessage: String?

    private let keychain: KeychainStore
    private let database: DatabaseManager
    private let openAIClient: OpenAIClientProtocol

    init(keychain: KeychainStore, database: DatabaseManager, openAIClient: OpenAIClientProtocol) {
        self.keychain = keychain
        self.database = database
        self.openAIClient = openAIClient
        endpoint = UserDefaults.standard.string(forKey: OpenAIClient.endpointKey) ?? OpenAIClient.defaultEndpoint
        model = UserDefaults.standard.string(forKey: OpenAIClient.modelKey) ?? OpenAIClient.defaultModel
        systemPrompt = UserDefaults.standard.string(forKey: OpenAIClient.systemPromptKey) ?? OpenAIClient.defaultSystemPrompt
        do {
            apiKey = try keychain.get(OpenAIClient.apiKeyKey) ?? ""
        } catch {
            apiKey = ""
        }
    }

    func saveAPISettings() {
        let normalizedEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPrompt = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)

        UserDefaults.standard.set(
            normalizedEndpoint.isEmpty ? OpenAIClient.defaultEndpoint : normalizedEndpoint,
            forKey: OpenAIClient.endpointKey
        )
        UserDefaults.standard.set(
            normalizedModel.isEmpty ? OpenAIClient.defaultModel : normalizedModel,
            forKey: OpenAIClient.modelKey
        )
        UserDefaults.standard.set(
            normalizedPrompt.isEmpty ? OpenAIClient.defaultSystemPrompt : normalizedPrompt,
            forKey: OpenAIClient.systemPromptKey
        )

        do {
            try keychain.set(apiKey, for: OpenAIClient.apiKeyKey)
            toast = "AI 配置已保存"
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

    func testConnection() {
        saveAPISettings()
        testResultMessage = nil
        isTestingConnection = true

        Task {
            defer { isTestingConnection = false }
            do {
                let result = try await openAIClient.testConnection()
                testResultMessage = result
                toast = "连接成功"
            } catch {
                testResultMessage = error.localizedDescription
                toast = "连接失败"
            }
        }
    }
}
