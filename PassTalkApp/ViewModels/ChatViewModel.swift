import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = [
        ChatMessage(role: .assistant, content: "嗨，我是 PassTalk。把账号密码告诉我，我帮你记住。", payloadType: .text)
    ]
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var isHistoryCollapsed: Bool = false

    private let repository: PasswordRepositoryProtocol
    private let openAIClient: OpenAIClientProtocol

    init(repository: PasswordRepositoryProtocol, openAIClient: OpenAIClientProtocol) {
        self.repository = repository
        self.openAIClient = openAIClient
    }

    func sendMessage() {
        sendMessage(text: inputText)
    }

    func sendMessage(text rawText: String) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        inputText = ""
        messages.append(ChatMessage(role: .user, content: text, payloadType: .text))

        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                let parse = try await openAIClient.parseMessage(text, history: messages)
                try await handleParseResult(parse)
            } catch {
                messages.append(ChatMessage(role: .assistant, content: "网络请求失败，请稍后重试。", payloadType: .text))
            }
        }
    }

    private func handleParseResult(_ parse: AIParseResult) async throws {
        switch parse.intent {
        case .save, .update:
            if !parse.missingFields.isEmpty, let follow = parse.followUpQuestion {
                messages.append(ChatMessage(role: .assistant, content: follow, payloadType: .followUp))
                return
            }

            guard
                let platform = parse.platform,
                let account = parse.account,
                let password = parse.password
            else {
                messages.append(ChatMessage(role: .assistant, content: "我还缺少必要信息，请补充平台、账号和密码。", payloadType: .followUp))
                return
            }

            let patch = EntryPatch(
                platform: platform,
                account: account,
                password: password,
                note: parse.note ?? "",
                primaryTag: parse.primaryTag ?? .other,
                secondaryTag: parse.secondaryTag
            )
            _ = try repository.createEntry(patch)
            messages.append(ChatMessage(role: .assistant, content: "已记好。\(platform) / \(account)", payloadType: .card))

        case .query:
            let keyword = (parse.queryKeyword?.isEmpty == false) ? parse.queryKeyword! : (parse.platform ?? "")
            let rows = try repository.searchEntries(keyword: keyword, selectedTag: nil)
            if let first = rows.first {
                let card = "\(first.platform)\n账号: \(first.account)\n密码: \(first.password)"
                messages.append(ChatMessage(role: .assistant, content: card, payloadType: .card))
            } else {
                messages.append(ChatMessage(role: .assistant, content: "没有找到相关条目。", payloadType: .text))
            }

        case .unknown:
            messages.append(ChatMessage(role: .assistant, content: parse.followUpQuestion ?? "我没完全理解，你可以直接说：平台 + 账号 + 密码。", payloadType: .text))
        }
    }
}
