import Foundation

enum PresetTag: String, CaseIterable, Codable, Identifiable {
    case social
    case shopping
    case finance
    case work
    case entertainment
    case email
    case devtools
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .social: return "社交"
        case .shopping: return "购物"
        case .finance: return "金融"
        case .work: return "工作"
        case .entertainment: return "娱乐"
        case .email: return "邮箱"
        case .devtools: return "开发工具"
        case .other: return "其他"
        }
    }
}
