import Foundation
import SwiftData

@Model
final class CustomField {
    var id: UUID
    var name: String
    var value: String          // Plain text for non-secret fields
    var encryptedValue: Data?  // Encrypted for secret fields
    var isSecret: Bool

    init(id: UUID = UUID(), name: String = "", value: String = "", encryptedValue: Data? = nil, isSecret: Bool = false) {
        self.id = id
        self.name = name
        self.value = value
        self.encryptedValue = encryptedValue
        self.isSecret = isSecret
    }
}