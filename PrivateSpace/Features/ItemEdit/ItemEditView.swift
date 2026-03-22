import SwiftUI
import SwiftData

struct ItemEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ItemEditViewModel

    init(mode: ItemEditMode) {
        _viewModel = StateObject(wrappedValue: ItemEditViewModel(mode: mode))
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Title Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("标题")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField("输入标题", text: $viewModel.title)
                            .padding()
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonCornerRadius))
                    }
                    .padding(.horizontal, AppSpacing.standardPadding)

                    // Fields
                    VStack(alignment: .leading, spacing: 8) {
                        Text("字段")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, AppSpacing.standardPadding)

                        List {
                            ForEach(viewModel.fields) { field in
                                FieldEditorRow(
                                    field: fieldBinding(for: field),
                                    onDelete: {
                                        if let index = viewModel.fields.firstIndex(where: { $0.id == field.id }) {
                                            viewModel.removeField(at: index)
                                        }
                                    },
                                    canDelete: viewModel.fields.count > 1
                                )
                            }
                        }
                        .listStyle(.plain)
                        .padding(.horizontal, AppSpacing.standardPadding)

                        Button {
                            viewModel.addField()
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("添加字段")
                            }
                            .font(.subheadline)
                            .foregroundColor(AppColors.primary)
                        }
                        .padding(.horizontal, AppSpacing.standardPadding)
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(AppColors.danger)
                            .padding(.horizontal, AppSpacing.standardPadding)
                    }

                    Spacer(minLength: 100)
                }
                .padding(.top, 16)
            }
        }
        .navigationTitle(viewModel.mode.isEdit ? "编辑条目" : "新建条目")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") {
                    do {
                        try viewModel.save(context: modelContext)
                        dismiss()
                    } catch {
                        viewModel.errorMessage = "保存失败"
                    }
                }
            }
        }
    }

    private func fieldBinding(for field: EditableField) -> Binding<EditableField> {
        Binding(
            get: { viewModel.fields.first(where: { $0.id == field.id }) ?? field },
            set: { newValue in
                if let index = viewModel.fields.firstIndex(where: { $0.id == field.id }) {
                    viewModel.fields[index] = newValue
                }
            }
        )
    }
}

struct FieldEditorRow: View {
    @Binding var field: EditableField
    let onDelete: () -> Void
    let canDelete: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                TextField("字段名", text: $field.name)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Toggle("", isOn: $field.isSecret)
                    .labelsHidden()
                    .scaleEffect(0.8)

                Text("私密")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if canDelete {
                    Button(action: onDelete) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(AppColors.danger)
                    }
                }
            }

            if field.isSecret {
                SecureField("字段值", text: $field.value)
                    .padding()
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonCornerRadius))
            } else {
                TextField("字段值", text: $field.value)
                    .padding()
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonCornerRadius))
            }
        }
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonCornerRadius))
    }
}

extension ItemEditMode {
    var isEdit: Bool {
        if case .edit = self { return true }
        return false
    }
}