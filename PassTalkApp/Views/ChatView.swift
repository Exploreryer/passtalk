import SwiftUI

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    let onTapVault: () -> Void
    let onTapSettings: () -> Void
    @FocusState private var isInputFocused: Bool

    var body: some View {
        ZStack {
            Color(white: 0.96).ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                GeometryReader { _ in
                    if isInitialEmptyState {
                        VStack(spacing: 0) {
                            emptyStateWelcomeCard
                                .padding(.horizontal, 14)
                                .padding(.top, 10)

                            Spacer(minLength: 20)

                            VStack(alignment: .leading, spacing: 10) {
                                Text("试试这样说")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 4)
                                quickActions
                            }
                            .padding(.horizontal, 14)
                            .padding(.bottom, 12)
                        }
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(viewModel.messages) { message in
                                        bubble(message)
                                            .id(message.id)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.top, 10)
                                .padding(.bottom, 14)
                            }
                            .scrollDismissesKeyboard(.interactively)
                            .onTapGesture {
                                isInputFocused = false
                            }
                            .onChange(of: viewModel.messages.count) { _ in
                                if let id = viewModel.messages.last?.id {
                                    withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                                }
                            }
                        }
                    }
                }

                inputBar
            }
        }
    }

    private var headerBar: some View {
        HStack {
            Button(action: onTapVault) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.secondary)
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.92))
                    .clipShape(Circle())
            }
            Spacer()
            Button(action: onTapSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.secondary)
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.92))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                TextField("跟我说…", text: $viewModel.inputText, axis: .vertical)
                    .focused($isInputFocused)
                    .lineLimit(1...3)
                    .font(.system(size: 16))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.85)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.02), radius: 2, y: 1)

            Button {
                viewModel.sendMessage()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 36, height: 36)
                    .background(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.35) : Color(red: 0.30, green: 0.30, blue: 0.32))
                    .clipShape(Circle())
            }
            .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(Color(white: 0.96))
    }

    private var isInitialEmptyState: Bool {
        viewModel.messages.count <= 1
    }

    private var emptyStateWelcomeCard: some View {
        HStack(alignment: .top, spacing: 8) {
            OnboardingLogoMark()
                .frame(width: 22, height: 22)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text("嗨👋 我是 PassTalk")
                    .font(.system(size: 14, weight: .semibold))
                Text("把账号密码告诉我，我帮你记住")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.02), radius: 2, y: 1)
    }

    private var quickActions: some View {
        VStack(spacing: 10) {
            quickActionRow(text: "帮我记一下 GitHub 密码", icon: "arrow.turn.down.right")
            quickActionRow(text: "我的 Spotify 账号是什么？", icon: "magnifyingglass")
            quickActionRow(text: "Notion：alex@gmail.com，Xxj93k", icon: "arrow.turn.down.right")
        }
        .padding(.top, 4)
    }

    private func quickActionRow(text: String, icon: String) -> some View {
        Button {
            viewModel.sendMessage(text: text)
        } label: {
            HStack(spacing: 8) {
                Text(text)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.secondary.opacity(0.9))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(Color.white.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func bubble(_ message: ChatMessage) -> some View {
        HStack(alignment: .top) {
            if message.role == .assistant {
                Text(message.content)
                    .font(.system(size: 14))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Spacer(minLength: 42)
            } else {
                Spacer(minLength: 42)
                Text(message.content)
                    .font(.system(size: 14))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .foregroundStyle(Color.white)
                    .background(Color(red: 0.20, green: 0.20, blue: 0.22))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

private struct OnboardingLogoMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(white: 0.96))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.gray.opacity(0.12), lineWidth: 0.5)
                }
            HStack(spacing: 3) {
                Circle().fill(Color.gray.opacity(0.6)).frame(width: 4, height: 4)
                Circle().fill(Color.gray.opacity(0.35)).frame(width: 4, height: 4)
                Circle().fill(Color.orange).frame(width: 4, height: 4)
            }
        }
    }
}
