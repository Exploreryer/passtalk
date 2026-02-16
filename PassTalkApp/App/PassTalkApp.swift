import SwiftUI

@main
struct PassTalkApp: App {
    @StateObject private var container = AppContainer.bootstrap()

    var body: some Scene {
        WindowGroup {
            RootContainerView()
                .environmentObject(container)
        }
    }
}
