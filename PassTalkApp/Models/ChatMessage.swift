import Foundation

enum ChatRole: String, Codable {
    case user
    case assistant
}

enum ChatPayloadType: String, Codable {
    case text
    case card
    case followUp
}

struct ChatMessage: Identifiable, Codable {
    let id: String
    let role: ChatRole
    let content: String
    let payloadType: ChatPayloadType
    let createdAt: Date

    init(id: String = UUID().uuidString, role: ChatRole, content: String, payloadType: ChatPayloadType, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.payloadType = payloadType
        self.createdAt = createdAt
    }
}

struct AIParseResult: Codable {
    enum Intent: String, Codable {
        case save
        case query
        case update
        case unknown
    }

    var intent: Intent
    var platform: String?
    var account: String?
    var password: String?
    var note: String?
    var primaryTag: PresetTag?
    var secondaryTag: PresetTag?
    var missingFields: [String]
    var followUpQuestion: String?
    var queryKeyword: String?

    static var unknown: AIParseResult {
        AIParseResult(
            intent: .unknown,
            platform: nil,
            account: nil,
            password: nil,
            note: nil,
            primaryTag: nil,
            secondaryTag: nil,
            missingFields: [],
            followUpQuestion: nil,
            queryKeyword: nil
        )
    }
}
