import Foundation

protocol OpenAIClientProtocol {
    func parseMessage(_ text: String, history: [ChatMessage]) async throws -> AIParseResult
    func testConnection() async throws -> String
}

final class OpenAIClient: OpenAIClientProtocol {
    private let keychain: KeychainStore
    private let session: URLSession
    static let apiKeyKey = "openai_api_key"
    static let endpointKey = "openai_endpoint"
    static let modelKey = "openai_model"
    static let defaultEndpoint = "https://api.openai.com/v1/chat/completions"
    static let defaultModel = "gpt-4.1-mini"
    static let defaultSystemPrompt = """
    你是 PassTalk 的对话助手「Talkie」。
    你的核心职责是帮助用户完成 PassTalk 密码管理相关任务（保存、查询、更新账号密码信息）。

    必须遵守：
    1) 你可以进行简短自然对话（例如问候、寒暄），但应尽快引导回产品动作：记录、查询或更新密码信息。
    2) 如果用户在打招呼（例如：你好、hi、hello、在吗），你需要简短友好回应，并引导用户提供可记录的信息（平台、账号、密码）。这类场景 intent=unknown。
    3) 当用户表达“保存/新增/记一下”且信息不完整时，intent=save，missingFields 必须列出缺失字段（只允许 platform/account/password），并给出一条明确 followUpQuestion 引导补齐。
    4) 当用户表达“更新/修改”时，intent=update。若缺字段，同样按第 3 条处理。
    5) 当用户表达“查找/查询/找回”时，intent=query，并尽量提取 queryKeyword（例如平台名或关键词）。
    6) 对于明显与产品无关且不适合继续展开的请求，intent=unknown，并用 followUpQuestion 把用户拉回产品动作（例如“你可以告诉我平台、账号、密码，我来帮你记住”）。
    7) 标签必须是：social/shopping/finance/work/entertainment/email/devtools/other。
    8) 只输出 JSON，不要输出任何额外文字、解释或 markdown。
    9) unknown 场景不要机械重复同一句模板。请结合最近对话上下文，给出自然、简短、不过度啰嗦的回应。
    10) 若用户正在补全上一条记录（例如先说了平台，下一句再给账号密码），要利用上下文补齐，不要重复索要已经给过的信息。

    字段定义：
    - intent: save/query/update/unknown
    - platform/account/password/note/primaryTag/secondaryTag/queryKeyword: 可为字符串或 null
    - missingFields: 字符串数组
    - followUpQuestion: 字符串或 null
    """

    init(keychain: KeychainStore, session: URLSession = .shared) {
        self.keychain = keychain
        self.session = session
    }

    func parseMessage(_ text: String, history: [ChatMessage]) async throws -> AIParseResult {
        guard let apiKey = try keychain.get(Self.apiKeyKey), !apiKey.isEmpty else {
            throw OpenAIClientRuntimeError.missingAPIKey
        }

        let config = loadConfiguration()
        let systemPrompt = config.systemPrompt
        let inputMessages = buildInputMessages(history: history, latestUserText: text, systemPrompt: systemPrompt)

        let outputSchema: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "properties": [
                "intent": ["type": "string", "enum": ["save", "query", "update", "unknown"]],
                "platform": ["type": ["string", "null"]],
                "account": ["type": ["string", "null"]],
                "password": ["type": ["string", "null"]],
                "note": ["type": ["string", "null"]],
                "primaryTag": ["type": ["string", "null"], "enum": ["social", "shopping", "finance", "work", "entertainment", "email", "devtools", "other", NSNull()]],
                "secondaryTag": ["type": ["string", "null"], "enum": ["social", "shopping", "finance", "work", "entertainment", "email", "devtools", "other", NSNull()]],
                "missingFields": ["type": "array", "items": ["type": "string"]],
                "followUpQuestion": ["type": ["string", "null"]],
                "queryKeyword": ["type": ["string", "null"]]
            ],
            "required": ["intent", "platform", "account", "password", "note", "primaryTag", "secondaryTag", "missingFields", "followUpQuestion", "queryKeyword"]
        ]

        let requestBody: [String: Any] = [
            "model": config.model,
            "input": inputMessages,
            "text": [
                "format": [
                    "type": "json_schema",
                    "name": "pass_talk_parse_result",
                    "schema": outputSchema,
                    "strict": true
                ]
            ]
        ]

        var request = URLRequest(url: config.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: buildRequestBody(
            for: config,
            responsesBody: requestBody,
            messages: inputMessages,
            responseFormat: ["type": "json_object"]
        ))

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw OpenAIClientRuntimeError.invalidHTTPResponse
        }
        guard 200..<300 ~= http.statusCode else {
            throw OpenAIClientRuntimeError.httpError(status: http.statusCode, detail: parseHttpErrorDetail(data: data))
        }

        guard let jsonText = try parseOutputText(data: data, config: config),
              let jsonData = jsonText.data(using: .utf8) else {
            let raw = String(data: data, encoding: .utf8) ?? ""
            throw OpenAIClientRuntimeError.invalidResponseFormat(raw: raw)
        }

        return try decodeParseResult(from: jsonData, rawText: jsonText)
    }

    func testConnection() async throws -> String {
        guard let apiKey = try keychain.get(Self.apiKeyKey), !apiKey.isEmpty else {
            throw ConnectionTestError.missingApiKey
        }

        let config = loadConfiguration()
        let systemPrompt = "回复 ok"
        let userText = "hi"

        let testMessages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": userText]
        ]
        let body = buildRequestBody(for: config, responsesBody: [
            "model": config.model,
            "input": testMessages,
            "text": ["format": ["type": "text"]]
        ], messages: testMessages)

        var request = URLRequest(url: config.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ConnectionTestError.unknown
        }

        guard 200..<300 ~= http.statusCode else {
            let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let errorBody = message?["error"] as? [String: Any]
            let detail = (errorBody?["message"] as? String) ?? String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw ConnectionTestError.httpError(status: http.statusCode, detail: detail)
        }

        return "连接成功\nEndpoint: \(config.endpoint.absoluteString)\nModel: \(config.model)"
    }
}

enum ConnectionTestError: LocalizedError {
    case missingApiKey
    case unknown
    case httpError(status: Int, detail: String)

    var errorDescription: String? {
        switch self {
        case .missingApiKey: return "请先填写并保存 API Key"
        case .unknown: return "连接失败"
        case .httpError(let status, let detail): return "HTTP \(status): \(detail)"
        }
    }
}

private extension OpenAIClient {
    struct AIProviderConfiguration {
        let endpoint: URL
        let model: String
        let systemPrompt: String

        var usesChatCompletions: Bool {
            endpoint.path.hasSuffix("/chat/completions")
        }
    }

    func loadConfiguration() -> AIProviderConfiguration {
        let defaults = UserDefaults.standard
        let rawEndpoint = defaults.string(forKey: Self.endpointKey) ?? Self.defaultEndpoint
        let endpoint = normalizedEndpoint(from: rawEndpoint)
        let model = normalizedModel(from: defaults.string(forKey: Self.modelKey))
        let systemPrompt = Self.defaultSystemPrompt
        return AIProviderConfiguration(endpoint: endpoint, model: model, systemPrompt: systemPrompt)
    }

    func normalizedModel(from raw: String?) -> String {
        let candidate = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return candidate.isEmpty ? Self.defaultModel : candidate
    }

    func normalizedEndpoint(from raw: String?) -> URL {
        let candidate = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty, var components = URLComponents(string: candidate), components.scheme != nil, components.host != nil else {
            return URL(string: Self.defaultEndpoint)!
        }

        let path = components.path.lowercased()
        if path.hasSuffix("/responses") || path.hasSuffix("/chat/completions") {
            return components.url ?? URL(string: Self.defaultEndpoint)!
        }

        // 第三方兼容服务通常只支持 /v1/chat/completions，默认使用该路径
        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if basePath.isEmpty {
            components.path = "/v1/chat/completions"
        } else {
            components.path = "/\(basePath)/v1/chat/completions"
        }

        return components.url ?? URL(string: Self.defaultEndpoint)!
    }

    func buildRequestBody(
        for config: AIProviderConfiguration,
        responsesBody: [String: Any],
        messages: [[String: Any]],
        responseFormat: [String: Any]? = nil
    ) -> [String: Any] {
        if config.usesChatCompletions {
            var body: [String: Any] = [
                "model": config.model,
                "messages": messages,
                "temperature": 0
            ]
            if let responseFormat {
                body["response_format"] = responseFormat
            }
            return body
        }
        return responsesBody
    }

    func buildInputMessages(history: [ChatMessage], latestUserText: String, systemPrompt: String) -> [[String: Any]] {
        var messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt]
        ]

        let recentHistory = history.suffix(12)
        if recentHistory.isEmpty {
            messages.append(["role": "user", "content": latestUserText])
            return messages
        }

        for message in recentHistory {
            let role = message.role == .assistant ? "assistant" : "user"
            messages.append([
                "role": role,
                "content": message.content
            ])
        }

        return messages
    }

    func parseHttpErrorDetail(data: Data) -> String {
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let err = obj["error"] as? [String: Any],
           let msg = err["message"] as? String {
            return msg
        }
        return String(data: data, encoding: .utf8) ?? "未知错误"
    }

    func parseOutputText(data: Data, config: AIProviderConfiguration) throws -> String? {
        if config.usesChatCompletions {
            let wrapper = try ChatCompletionsResponseWrapper(data: data)
            return wrapper.outputText
        }
        let wrapper = try JSONDecoder().decode(OpenAIResponseWrapper.self, from: data)
        return wrapper.outputText
    }

    func decodeParseResult(from jsonData: Data, rawText: String) throws -> AIParseResult {
        if let strict = try? JSONDecoder().decode(AIParseResult.self, from: jsonData) {
            return strict
        }

        guard let object = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw OpenAIClientRuntimeError.invalidParseResultJSON(
                raw: rawText,
                underlying: "无法解析为 JSON 对象"
            )
        }

        let intent = AIParseResult.Intent(rawValue: normalizedLowercasedString(object["intent"]) ?? "unknown") ?? .unknown
        let platform = normalizedString(object["platform"])
        let account = normalizedString(object["account"])
        let password = normalizedString(object["password"])
        let note = normalizedString(object["note"]) ?? ""
        let primaryTag = PresetTag(rawValue: normalizedLowercasedString(object["primaryTag"]) ?? "")
        let secondaryTag = PresetTag(rawValue: normalizedLowercasedString(object["secondaryTag"]) ?? "")
        let queryKeyword = normalizedString(object["queryKeyword"])
        var missingFields = normalizedStringArray(object["missingFields"])
        let followUpQuestion = normalizedString(object["followUpQuestion"])

        if missingFields.isEmpty, intent == .save || intent == .update {
            if platform == nil { missingFields.append("platform") }
            if account == nil { missingFields.append("account") }
            if password == nil { missingFields.append("password") }
        }

        return AIParseResult(
            intent: intent,
            platform: platform,
            account: account,
            password: password,
            note: note,
            primaryTag: primaryTag,
            secondaryTag: secondaryTag,
            missingFields: missingFields,
            followUpQuestion: followUpQuestion,
            queryKeyword: queryKeyword
        )
    }

    func normalizedString(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func normalizedLowercasedString(_ value: Any?) -> String? {
        normalizedString(value)?.lowercased()
    }

    func normalizedStringArray(_ value: Any?) -> [String] {
        guard let values = value as? [Any] else { return [] }
        return values.compactMap { item in
            guard let text = item as? String else { return nil }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
    }
}

enum OpenAIClientRuntimeError: LocalizedError {
    case missingAPIKey
    case invalidHTTPResponse
    case httpError(status: Int, detail: String)
    case invalidResponseFormat(raw: String)
    case invalidParseResultJSON(raw: String, underlying: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "请先在设置中填写并保存 API Key。"
        case .invalidHTTPResponse:
            return "请求失败：未收到有效的 HTTP 响应。"
        case .httpError(let status, let detail):
            return "API 请求失败（HTTP \(status)）：\(detail)"
        case .invalidResponseFormat:
            return "模型返回格式无法解析。"
        case .invalidParseResultJSON(_, let underlying):
            return "模型输出 JSON 不符合预期：\(underlying)"
        }
    }
}

private struct OpenAIResponseWrapper: Decodable {
    struct OutputItem: Decodable {
        struct ContentItem: Decodable {
            let type: String?
            let text: String?
        }

        let content: [ContentItem]?
    }

    let output: [OutputItem]?

    var outputText: String? {
        output?
            .flatMap { $0.content ?? [] }
            .first(where: { $0.type == "output_text" })?
            .text
    }
}

private struct ChatCompletionsResponseWrapper {
    let outputText: String?

    init(data: Data) throws {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let root = object as? [String: Any],
              let choices = root["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any] else {
            outputText = nil
            return
        }

        if let text = message["content"] as? String {
            outputText = Self.extractJSONObjectString(from: text)
            return
        }

        if let parts = message["content"] as? [[String: Any]] {
            let combined = parts.compactMap { part -> String? in
                (part["text"] as? String) ?? (part["content"] as? String)
            }.joined(separator: "\n")
            outputText = Self.extractJSONObjectString(from: combined)
            return
        }

        outputText = nil
    }

    private static func extractJSONObjectString(from text: String) -> String {
        var work = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // 去除 markdown 代码块 ```json ... ``` 或 ``` ... ```
        if work.hasPrefix("```") {
            work = work
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let start = work.firstIndex(of: "{"),
              let end = work.lastIndex(of: "}") else {
            return work
        }
        return String(work[start...end])
    }
}
