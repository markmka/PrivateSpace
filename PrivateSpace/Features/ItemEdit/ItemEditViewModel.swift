import SwiftUI
import SwiftData

enum ItemEditMode {
    case create(type: ItemType)
    case edit(item: VaultItem)
}

@MainActor
final class ItemEditViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var selectedType: ItemType = .password
    @Published var fields: [EditableField] = []
    @Published var errorMessage: String?

    let mode: ItemEditMode
    private var existingItem: VaultItem?

    init(mode: ItemEditMode) {
        self.mode = mode

        switch mode {
        case .create(let type):
            selectedType = type
            setupPresetFields(for: type)
        case .edit(let item):
            existingItem = item
            title = item.title
            selectedType = item.type
            fields = item.fields.map { EditableField(from: $0) }
        }
    }

    func setupPresetFields(for type: ItemType) {
        fields = []
        switch type {
        case .password:
            fields = [
                EditableField(name: "网站", isSecret: false),
                EditableField(name: "用户名", isSecret: false),
                EditableField(name: "密码", isSecret: true)
            ]
        case .privateKey:
            fields = [
                EditableField(name: "名称", isSecret: false),
                EditableField(name: "私钥", isSecret: true),
                EditableField(name: "备注", isSecret: false)
            ]
        case .note:
            fields = [
                EditableField(name: "标题", isSecret: false),
                EditableField(name: "内容", isSecret: true)
            ]
        case .other:
            fields = [EditableField(name: "字段1", isSecret: false)]
        case .custom:
            fields = [EditableField(name: "字段1", isSecret: false)]
        }
    }

    func addField() {
        fields.append(EditableField(name: "新字段", isSecret: false))
    }

    func removeField(at index: Int) {
        guard fields.count > 1 else { return }
        fields.remove(at: index)
    }

    func save(context: ModelContext) throws {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "请输入标题"
            return
        }

        switch mode {
        case .create:
            let item = VaultItem(type: selectedType, title: title)
            for editableField in fields {
                let field = CustomField(
                    name: editableField.name,
                    value: editableField.isSecret ? "" : editableField.value,
                    encryptedValue: editableField.isSecret ? try? EncryptionService.shared.encryptField(value: editableField.value) : nil,
                    isSecret: editableField.isSecret
                )
                item.fields.append(field)
            }
            context.insert(item)
        case .edit(let item):
            item.title = title
            item.type = selectedType
            item.modifiedAt = Date()

            for existingField in item.fields {
                context.delete(existingField)
            }
            item.fields.removeAll()

            for editableField in fields {
                let field = CustomField(
                    name: editableField.name,
                    value: editableField.isSecret ? "" : editableField.value,
                    encryptedValue: editableField.isSecret ? try? EncryptionService.shared.encryptField(value: editableField.value) : nil,
                    isSecret: editableField.isSecret
                )
                item.fields.append(field)
            }
        }

        errorMessage = nil
    }
}

struct EditableField: Identifiable {
    let id: UUID
    var name: String
    var value: String
    var isSecret: Bool

    init(id: UUID = UUID(), name: String = "", value: String = "", isSecret: Bool = false) {
        self.id = id
        self.name = name
        self.value = value
        self.isSecret = isSecret
    }

    init(from field: CustomField) {
        self.id = field.id
        self.name = field.name
        self.value = field.isSecret
            ? (try? EncryptionService.shared.decryptField(data: field.encryptedValue!)) ?? ""
            : field.value
        self.isSecret = field.isSecret
    }
}