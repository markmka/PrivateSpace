import SwiftUI

enum AppColors {
    static let primary = Color(hex: "007AFF")
    static let success = Color(hex: "34C759")
    static let warning = Color(hex: "FF9500")
    static let danger = Color(hex: "FF2D55")
    static let background = Color(hex: "F2F2F7")
    static let cardBackground = Color.white
    static let darkBackground = Color.black
}

enum AppSpacing {
    static let cardCornerRadius: CGFloat = 16
    static let buttonCornerRadius: CGFloat = 12
    static let iconCornerRadius: CGFloat = 10
    static let fabSize: CGFloat = 56
    static let standardPadding: CGFloat = 16
    static let smallPadding: CGFloat = 8
}

enum ItemTypeMetadata {
    static func color(for type: ItemType) -> Color {
        switch type {
        case .password: return Color(hex: "007AFF")
        case .privateKey: return Color(hex: "34C759")
        case .note: return Color(hex: "FF9500")
        case .other: return Color(hex: "FF2D55")
        case .custom: return Color(hex: "5856D6")
        }
    }

    static func backgroundColor(for type: ItemType) -> Color {
        color(for: type).opacity(0.12)
    }

    static func icon(for type: ItemType) -> String {
        type.iconName
    }
}
