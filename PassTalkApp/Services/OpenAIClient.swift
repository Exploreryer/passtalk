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
    static let systemPromptKey = "openai_system_prompt"
    static let defaultEndpoint = "https://api.openai.com/v1/chat/completions"
    static let defaultModel = "gpt-4.1-mini"
    static let defaultSystemPrompt = """
        你是 PassTalk 的解析器。仅输出 JSON，不要输出其他文字。
        根据用户输入解析出：intent( save/query/update/unknown )、platform、account、password、note、primaryTag、secondaryTag、missingFields、followUpQuestion、queryKeyword。
        标签必须在 social/shopping/finance/work/entertainment/email/devtools/other。
        输出格式示例：{"intent":"save","platform":"GitHub","account":"user@example.com","password":"xxx","note":"","primaryTag":"work","secondaryTag":null,"missingFields":[],"followUpQuestion":null,"queryKeyword":null}
        """

    init(keychain: KeychainStore, session: URLSession = .shared) {
        self.keychain = keychain
        self.session = session
    }

    func parseMessage(_ text: String, history: [ChatMessage]) async throws -> AIParseResult {
        guard let apiKey = try keychain.get(Self.apiKeyKey), !apiKey.isEmpty else {
            return AIParseResult(
                intent: .unknown,
                platform: nil,
                account: nil,
                password: nil,
                note: nil,
                primaryTag: nil,
                secondaryTag: nil,
                missingFields: [],
                followUpQuestion: "请先在设置里配置 OpenAI API Key。",
                queryKeyword: nil
            )
        }

        let config = loadConfiguration()
        let systemPrompt = config.systemPrompt

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
            "input": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
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
        request.httpBody = try JSONSerialization.data(withJSONObject: buildRequestBody(for: config, responsesBody: requestBody, systemPrompt: systemPrompt, userText: text))

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            return AIParseResult(intent: .unknown, platform: nil, account: nil, password: nil, note: nil, primaryTag: nil, secondaryTag: nil, missingFields: [], followUpQuestion: "请求异常，请稍后重试。", queryKeyword: nil)
        }
        guard 200..<300 ~= http.statusCode else {
            let hint = parseHttpErrorHint(data: data, status: http.statusCode)
            return AIParseResult(intent: .unknown, platform: nil, account: nil, password: nil, note: nil, primaryTag: nil, secondaryTag: nil, missingFields: [], followUpQuestion: hint, queryKeyword: nil)
        }

        guard let jsonText = try parseOutputText(data: data, config: config),
              let jsonData = jsonText.data(using: .utf8) else {
            return AIParseResult(intent: .unknown, platform: nil, account: nil, password: nil, note: nil, primaryTag: nil, secondaryTag: nil, missingFields: [], followUpQuestion: "模型返回格式无法解析，请检查 System Prompt 或尝试更换模型。", queryKeyword: nil)
        }

        do {
            return try JSONDecoder().decode(AIParseResult.self, from: jsonData)
        } catch {
            return AIParseResult(intent: .unknown, platform: nil, account: nil, password: nil, note: nil, primaryTag: nil, secondaryTag: nil, missingFields: [], followUpQuestion: "模型返回的 JSON 格式不符，请检查 System Prompt 或尝试更换模型。", queryKeyword: nil)
        }
    }

    func testConnection() async throws -> String {
        guard let apiKey = try keychain.get(Self.apiKeyKey), !apiKey.isEmpty else {
            throw ConnectionTestError.missingApiKey
        }

        let config = loadConfiguration()
        let systemPrompt = "回复 ok"
        let userText = "hi"

        let body = buildRequestBody(for: config, responsesBody: [
            "model": config.model,
            "input": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userText]
            ],
            "text": ["format": ["type": "text"]]
        ], systemPrompt: systemPrompt, userText: userText)

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
        let systemPrompt = normalizedSystemPrompt(from: defaults.string(forKey: Self.systemPromptKey))
        return AIProviderConfiguration(endpoint: endpoint, model: model, systemPrompt: systemPrompt)
    }

    func normalizedSystemPrompt(from raw: String?) -> String {
        let candidate = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return candidate.isEmpty ? Self.defaultSystemPrompt : candidate
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
        systemPrompt: String,
        userText: String
    ) -> [String: Any] {
        if config.usesChatCompletions {
            return [
                "model": config.model,
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": userText]
                ],
                "temperature": 0
            ]
        }
        return responsesBody
    }

    func parseHttpErrorHint(data: Data, status: Int) -> String {
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let err = obj["error"] as? [String: Any],
           let msg = err["message"] as? String {
            return "API 错误 (\(status)): \(msg)"
        }
        return "API 请求失败 (\(status))，请检查 Endpoint、Model 和 API Key。"
    }

    func parseOutputText(data: Data, config: AIProviderConfiguration) throws -> String? {
        if config.usesChatCompletions {
            let wrapper = try ChatCompletionsResponseWrapper(data: data)
            return wrapper.outputText
        }
        let wrapper = try JSONDecoder().decode(OpenAIResponseWrapper.self, from: data)
        return wrapper.outputText
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
