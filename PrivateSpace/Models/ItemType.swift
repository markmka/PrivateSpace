import Foundation

enum ItemType: String, Codable, CaseIterable, Identifiable {
    case password
    case privateKey
    case note
    case other
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .password: return "密码"
        case .privateKey: return "私钥"
        case .note: return "安全笔记"
        case .other: return "其他"
        case .custom: return "自定义"
        }
    }

    var iconName: String {
        switch self {
        case .password: return "key.fill"
        case .privateKey: return "lock.fill"
        case .note: return "note.text"
        case .other: return "folder.fill"
        case .custom: return "square.grid.2x2.fill"
        }
    }

    var accentColor: String {
        switch self {
        case .password: return "007AFF"
        case .privateKey: return "34C759"
        case .note: return "FF9500"
        case .other: return "FF2D55"
        case .custom: return "5856D6"
        }
    }
}