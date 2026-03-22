import SwiftUI
import SwiftData

struct ItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var item: VaultItem
    @StateObject private var viewModel = ItemDetailViewModel()
    @State private var showingDeleteAlert = false

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Header Card
                    VStack(spacing: 12) {
                        Image(systemName: item.type.iconName)
                            .font(.system(size: 32))
                            .foregroundColor(ItemTypeMetadata.color(for: item.type))
                            .frame(width: 64, height: 64)
                            .background(ItemTypeMetadata.backgroundColor(for: item.type))
                            .clipShape(RoundedRectangle(cornerRadius: 16))

                        Text(item.title.isEmpty ? "无标题" : item.title)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(item.type.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .cardStyle()
                    .padding(.horizontal, AppSpacing.standardPadding)

                    // Fields Card
                    VStack(spacing: 0) {
                        ForEach(item.fields) { field in
                            SecretFieldView(
                                name: field.name,
                                value: .constant(viewModel.getFieldValue(field)),
                                isRevealed: Binding(
                                    get: { viewModel.isRevealed[field.id] ?? false },
                                    set: { _ in viewModel.toggleReveal(for: field.id) }
                                ),
                                isSecret: field.isSecret
                            ) {
                                viewModel.copyField(field)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)

                            if field.id != item.fields.last?.id {
                                Divider().padding(.leading, 20)
                            }
                        }
                    }
                    .cardStyle()
                    .padding(.horizontal, AppSpacing.standardPadding)

                    Spacer(minLength: 100)
                }
                .padding(.top, 16)
            }

            // Toast
            if viewModel.showingCopiedToast {
                VStack {
                    Spacer()
                    Text("已复制，30秒后清除")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.75))
                        .clipShape(Capsule())
                        .padding(.bottom, 100)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    NavigationLink {
                        ItemEditView(mode: .edit(item: item))
                    } label: {
                        Text("编辑")
                    }

                    Button {
                        showingDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(AppColors.danger)
                    }
                }
            }
        }
        .alert("删除条目", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                modelContext.delete(item)
                dismiss()
            }
        } message: {
            Text("确定要删除这个条目吗？此操作不可撤销。")
        }
    }
}