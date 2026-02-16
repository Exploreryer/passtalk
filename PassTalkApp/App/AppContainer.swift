import Foundation

@MainActor
final class AppContainer: ObservableObject {
    let database: DatabaseManager
    let passwordRepository: PasswordRepositoryProtocol
    let keychain: KeychainStore
    let openAIClient: OpenAIClientProtocol
    let importService: ImportServiceProtocol
    let exportService: ExportServiceProtocol
    let chatViewModel: ChatViewModel
    let vaultViewModel: VaultViewModel

    @Published var hasCompletedOnboarding: Bool

    init(
        database: DatabaseManager,
        passwordRepository: PasswordRepositoryProtocol,
        keychain: KeychainStore,
        openAIClient: OpenAIClientProtocol,
        importService: ImportServiceProtocol,
        exportService: ExportServiceProtocol,
        hasCompletedOnboarding: Bool
    ) {
        self.database = database
        self.passwordRepository = passwordRepository
        self.keychain = keychain
        self.openAIClient = openAIClient
        self.importService = importService
        self.exportService = exportService
        self.chatViewModel = ChatViewModel(repository: passwordRepository, openAIClient: openAIClient)
        self.vaultViewModel = VaultViewModel(repository: passwordRepository)
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }

    static func bootstrap() -> AppContainer {
        let db = DatabaseManager(databaseName: "passtalk.sqlite")
        let repository = SQLitePasswordRepository(database: db, deviceIDProvider: DeviceIDProvider.shared)
        let keychain = KeychainStore(service: "com.passtalk.app")
        let client = OpenAIClient(keychain: keychain)
        let importService = ImportService(repository: repository)
        let exportService = ExportService(repository: repository)
        let onboardingDone = UserDefaults.standard.bool(forKey: UserDefaultsKeys.didCompleteOnboarding)

        return AppContainer(
            database: db,
            passwordRepository: repository,
            keychain: keychain,
            openAIClient: client,
            importService: importService,
            exportService: exportService,
            hasCompletedOnboarding: onboardingDone
        )
    }

    func markOnboardingCompleted() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: UserDefaultsKeys.didCompleteOnboarding)
    }

    func resetOnboarding() {
        hasCompletedOnboarding = false
        UserDefaults.standard.set(false, forKey: UserDefaultsKeys.didCompleteOnboarding)
    }
}

enum UserDefaultsKeys {
    static let didCompleteOnboarding = "did_complete_onboarding"
}
