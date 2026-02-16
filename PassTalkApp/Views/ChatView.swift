import SwiftUI

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    let onTapSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: onTapSettings) {
                    Image(systemName: "gearshape")
                        .font(.title3)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if viewModel.isHistoryCollapsed {
                Button("展开历史") {
                    viewModel.isHistoryCollapsed = false
                }
                .padding(.bottom, 8)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            bubble(message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let id = viewModel.messages.last?.id {
                        withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("跟我说...", text: $viewModel.inputText)
                    .textFieldStyle(.roundedBorder)
                Button {
                    viewModel.sendMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .padding(8)
                }
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .background(Color.white)
        }
        .background(Color(white: 0.96))
    }

    @ViewBuilder
    private func bubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.role == .assistant {
                Text(message.content)
                    .padding(12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 40)
                Text(message.content)
                    .padding(12)
                    .foregroundStyle(Color.white)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}
