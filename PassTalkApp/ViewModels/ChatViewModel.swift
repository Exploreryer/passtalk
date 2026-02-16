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
    private let onEntrySaved: (() -> Void)?
    private var pendingDraft: PendingEntryDraft?

    init(
        repository: PasswordRepositoryProtocol,
        openAIClient: OpenAIClientProtocol,
        onEntrySaved: (() -> Void)? = nil
    ) {
        self.repository = repository
        self.openAIClient = openAIClient
        self.onEntrySaved = onEntrySaved
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
                messages.append(ChatMessage(role: .assistant, content: error.localizedDescription, payloadType: .text))
            }
        }
    }

    private func handleParseResult(_ parse: AIParseResult) async throws {
        switch parse.intent {
        case .save, .update:
            let draft = mergeDraft(from: parse)
            if let patch = draft.toEntryPatchIfComplete() {
                _ = try repository.createEntry(patch)
                pendingDraft = nil
                onEntrySaved?()
                messages.append(ChatMessage(role: .assistant, content: "已记好。\(patch.platform) / \(patch.account)", payloadType: .card))
                return
            }

            pendingDraft = draft
            let follow = parse.followUpQuestion ?? draft.followUpQuestion
            messages.append(ChatMessage(role: .assistant, content: follow, payloadType: .followUp))

        case .query:
            pendingDraft = nil
            let keyword = (parse.queryKeyword?.isEmpty == false) ? parse.queryKeyword! : (parse.platform ?? "")
            let rows = try repository.searchEntries(keyword: keyword, selectedTag: nil)
            if let first = rows.first {
                let card = "\(first.platform)\n账号: \(first.account)\n密码: \(first.password)"
                messages.append(ChatMessage(role: .assistant, content: card, payloadType: .card))
            } else {
                messages.append(ChatMessage(role: .assistant, content: "没有找到相关条目。", payloadType: .text))
            }

        case .unknown:
            if let existing = pendingDraft {
                let draft = mergeDraft(from: parse, base: existing)
                if let patch = draft.toEntryPatchIfComplete() {
                    _ = try repository.createEntry(patch)
                    pendingDraft = nil
                    onEntrySaved?()
                    messages.append(ChatMessage(role: .assistant, content: "已记好。\(patch.platform) / \(patch.account)", payloadType: .card))
                    return
                }

                pendingDraft = draft
                let follow = parse.followUpQuestion ?? draft.followUpQuestion
                messages.append(ChatMessage(role: .assistant, content: follow, payloadType: .followUp))
                return
            }

            messages.append(ChatMessage(role: .assistant, content: parse.followUpQuestion ?? "我在，你可以告诉我平台、账号和密码，我帮你记住。", payloadType: .text))
        }
    }

    private func mergeDraft(from parse: AIParseResult, base: PendingEntryDraft? = nil) -> PendingEntryDraft {
        PendingEntryDraft(
            platform: normalized(parse.platform) ?? base?.platform,
            account: normalized(parse.account) ?? base?.account,
            password: normalized(parse.password) ?? base?.password,
            note: parse.note ?? base?.note ?? "",
            primaryTag: parse.primaryTag ?? base?.primaryTag ?? .other
        )
    }

    private func normalized(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

private struct PendingEntryDraft {
    var platform: String?
    var account: String?
    var password: String?
    var note: String
    var primaryTag: PresetTag

    var missingFields: [String] {
        var fields: [String] = []
        if platform == nil { fields.append("平台") }
        if account == nil { fields.append("账号") }
        if password == nil { fields.append("密码") }
        return fields
    }

    var followUpQuestion: String {
        "还差\(missingFields.joined(separator: "、"))，补充后我就帮你记住。"
    }

    func toEntryPatchIfComplete() -> EntryPatch? {
        guard let platform, let account, let password else { return nil }
        return EntryPatch(
            platform: platform,
            account: account,
            password: password,
            note: note,
            primaryTag: primaryTag,
            secondaryTag: nil
        )
    }
}
