import SwiftUI

struct FilterPillsView: View {
    @Binding var selectedType: ItemType?
    let customTypes: [CustomItemType]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterPill(title: "全部", isSelected: selectedType == nil) {
                    selectedType = nil
                }

                ForEach(ItemType.allCases.filter { $0 != .custom }) { type in
                    FilterPill(
                        title: type.displayName,
                        icon: type.iconName,
                        isSelected: selectedType == type
                    ) {
                        selectedType = type
                    }
                }
            }
            .padding(.horizontal, AppSpacing.standardPadding)
        }
    }
}

struct FilterPill: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.subheadline)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? AppColors.primary : Color.white)
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
}
