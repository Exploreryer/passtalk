import SwiftUI

@main
struct PassTalkApp: App {
    @StateObject private var container = AppContainer.bootstrap()

    init() {
        AppRuntimeDiagnostics.install()
    }

    var body: some Scene {
        WindowGroup {
            RootContainerView()
                .environmentObject(container)
        }
    }
}
