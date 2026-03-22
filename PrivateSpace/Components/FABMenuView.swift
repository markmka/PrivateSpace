import SwiftUI

struct FABMenuView: View {
    @Binding var isExpanded: Bool
    let onSelectType: (ItemType) -> Void
    let customTypes: [CustomItemType]

    var body: some View {
        ZStack {
            if isExpanded {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            isExpanded = false
                        }
                    }
            }

            VStack(alignment: .trailing, spacing: 12) {
                if isExpanded {
                    ForEach(menuItems, id: \.type) { item in
                        MenuItemView(
                            title: item.title,
                            icon: item.icon,
                            color: item.color
                        ) {
                            onSelectType(item.type)
                            withAnimation(.spring(response: 0.3)) {
                                isExpanded = false
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .scale(scale: 0.8).combined(with: .opacity)
                        ))
                    }
                }

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "x" : "plus")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(width: AppSpacing.fabSize, height: AppSpacing.fabSize)
                        .background(isExpanded ? Color.gray : AppColors.primary)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                }
                .rotationEffect(.degrees(isExpanded ? 45 : 0))
            }
            .padding(.trailing, 24)
            .padding(.bottom, 24)
        }
    }

    private var menuItems: [(title: String, icon: String, color: Color, type: ItemType)] {
        [
            ("密码", "key.fill", AppColors.primary, .password),
            ("私钥", "lock.fill", AppColors.success, .privateKey),
            ("安全笔记", "note.text", AppColors.warning, .note),
            ("其他", "folder.fill", AppColors.danger, .other)
        ]
    }
}

struct MenuItemView: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)

                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(color)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            }
        }
    }
}
