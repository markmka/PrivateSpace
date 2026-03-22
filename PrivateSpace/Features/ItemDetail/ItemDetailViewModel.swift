import SwiftUI

@MainActor
final class ItemDetailViewModel: ObservableObject {
    @Published var isRevealed: [UUID: Bool] = [:]
    @Published var copiedFieldId: UUID? = nil
    @Published var showingCopiedToast: Bool = false

    func toggleReveal(for fieldId: UUID) {
        isRevealed[fieldId] = !(isRevealed[fieldId] ?? false)
    }

    func copyField(_ field: CustomField) {
        let value = field.isSecret && field.encryptedValue != nil
            ? (try? EncryptionService.shared.decryptField(data: field.encryptedValue!)) ?? ""
            : field.value

        ClipboardService.shared.copy(value, sensitive: field.isSecret)
        copiedFieldId = field.id
        showingCopiedToast = true

        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                showingCopiedToast = false
            }
        }
    }

    func getFieldValue(_ field: CustomField) -> String {
        if field.isSecret {
            if isRevealed[field.id] == true {
                do {
                    return try EncryptionService.shared.decryptField(data: field.encryptedValue!)
                } catch {
                    return "解密失败"
                }
            } else {
                return String(repeating: "•", count: 12)
            }
        }
        return field.value
    }
}