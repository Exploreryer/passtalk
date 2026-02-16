import Foundation

protocol OpenAIClientProtocol {
    func parseMessage(_ text: String, history: [ChatMessage]) async throws -> AIParseResult
}

final class OpenAIClient: OpenAIClientProtocol {
    private let keychain: KeychainStore
    private let session: URLSession
    private let endpoint = URL(string: "https://api.openai.com/v1/responses")!
    static let apiKeyKey = "openai_api_key"

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

        let systemPrompt = """
        你是 PassTalk 的解析器。仅输出 JSON，字段必须符合 schema。
        标签必须在 social/shopping/finance/work/entertainment/email/devtools/other。
        默认只给 1 个标签，最多 2 个。
        """

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
            "model": "gpt-4.1-mini",
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

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            return AIParseResult.unknown
        }

        let wrapper = try JSONDecoder().decode(OpenAIResponseWrapper.self, from: data)
        guard let jsonText = wrapper.outputText,
              let jsonData = jsonText.data(using: .utf8) else {
            return AIParseResult.unknown
        }

        do {
            return try JSONDecoder().decode(AIParseResult.self, from: jsonData)
        } catch {
            return AIParseResult.unknown
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
