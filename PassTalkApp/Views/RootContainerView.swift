import SwiftUI

struct RootContainerView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var offsetX: CGFloat = 0
    @State private var showSettings = false

    private let vaultWidthRatio: CGFloat = 0.92

    var body: some View {
        Group {
            if container.hasCompletedOnboarding {
                mainContent
            } else {
                OnboardingView {
                    container.markOnboardingCompleted()
                }
            }
        }
    }

    private var mainContent: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let vaultOffset = width * vaultWidthRatio

            ZStack(alignment: .leading) {
                VaultListView(viewModel: container.vaultViewModel)
                    .frame(width: width)
                    .offset(x: -vaultOffset + offsetX)

                ChatView(viewModel: container.chatViewModel, onTapSettings: {
                    showSettings = true
                })
                .frame(width: width)
                .offset(x: offsetX)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { value in
                            if offsetX == 0 && value.startLocation.x > 32 && value.translation.width > 0 {
                                return
                            }
                            let new = min(max(0, value.translation.width), vaultOffset)
                            offsetX = new
                        }
                        .onEnded { value in
                            let target = (value.translation.width > vaultOffset / 2) ? vaultOffset : 0
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                                offsetX = target
                            }
                        }
                )
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(
                    viewModel: SettingsViewModel(keychain: container.keychain, database: container.database),
                    importService: container.importService,
                    exportService: container.exportService,
                    onReplayOnboarding: { container.resetOnboarding() }
                )
            }
        }
    }
}
