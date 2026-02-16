import SwiftUI

struct RootContainerView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var offsetX: CGFloat = 0
    @State private var showSettings = false
    @State private var dragStartOffsetX: CGFloat?

    private let vaultWidthRatio: CGFloat = 1.0
    private let edgeTriggerWidth: CGFloat = 32

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
                    .allowsHitTesting(offsetX > vaultOffset * 0.95)
                    .gesture(vaultPanelDragGesture(vaultOffset: vaultOffset))

                ChatView(
                    viewModel: container.chatViewModel,
                    onTapVault: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                            offsetX = vaultOffset
                        }
                    },
                    onTapSettings: {
                        showSettings = true
                    }
                )
                .frame(width: width)
                .offset(x: offsetX)
                .contentShape(Rectangle())
                .allowsHitTesting(offsetX < vaultOffset * 0.05)
                .gesture(chatPanelDragGesture(vaultOffset: vaultOffset))
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(
                    viewModel: SettingsViewModel(keychain: container.keychain, database: container.database, openAIClient: container.openAIClient),
                    importService: container.importService,
                    exportService: container.exportService,
                    onReplayOnboarding: { container.resetOnboarding() }
                )
            }
        }
    }

    private func chatPanelDragGesture(vaultOffset: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if abs(value.translation.width) <= abs(value.translation.height) {
                    return
                }

                if dragStartOffsetX == nil {
                    if offsetX == 0, value.startLocation.x > edgeTriggerWidth {
                        dragStartOffsetX = -1
                        return
                    }
                    dragStartOffsetX = offsetX
                }

                guard let startOffset = dragStartOffsetX, startOffset >= 0 else {
                    return
                }

                let proposed = startOffset + value.translation.width
                offsetX = min(max(0, proposed), vaultOffset)
            }
            .onEnded { value in
                defer { dragStartOffsetX = nil }

                if abs(value.translation.width) <= abs(value.translation.height) {
                    return
                }

                guard let startOffset = dragStartOffsetX, startOffset >= 0 else {
                    return
                }

                let predicted = min(max(0, startOffset + value.predictedEndTranslation.width), vaultOffset)
                let threshold = vaultOffset * 0.5
                let shouldOpen = offsetX > threshold || predicted > threshold
                withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                    offsetX = shouldOpen ? vaultOffset : 0
                }
            }
    }

    private func vaultPanelDragGesture(vaultOffset: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if abs(value.translation.width) <= abs(value.translation.height) {
                    return
                }

                if dragStartOffsetX == nil {
                    dragStartOffsetX = offsetX
                }

                guard let startOffset = dragStartOffsetX, startOffset >= 0 else {
                    return
                }

                let proposed = startOffset + value.translation.width
                offsetX = min(max(0, proposed), vaultOffset)
            }
            .onEnded { value in
                defer { dragStartOffsetX = nil }

                if abs(value.translation.width) <= abs(value.translation.height) {
                    return
                }

                guard let startOffset = dragStartOffsetX, startOffset >= 0 else {
                    return
                }

                let predicted = min(max(0, startOffset + value.predictedEndTranslation.width), vaultOffset)
                let threshold = vaultOffset * 0.5
                let shouldOpen = offsetX > threshold || predicted > threshold
                withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                    offsetX = shouldOpen ? vaultOffset : 0
                }
            }
    }
}
