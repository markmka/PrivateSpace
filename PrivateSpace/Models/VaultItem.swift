import Foundation
import SwiftData

@Model
final class VaultItem {
    @Attribute(.unique) var id: UUID
    var type: ItemType
    var title: String
    @Relationship(deleteRule: .cascade) var fields: [CustomField]
    var customType: CustomItemType?
    var createdAt: Date
    var modifiedAt: Date

    init(id: UUID = UUID(), type: ItemType, title: String = "", fields: [CustomField] = [], customType: CustomItemType? = nil, createdAt: Date = Date(), modifiedAt: Date = Date()) {
        self.id = id
        self.type = type
        self.title = title
        self.fields = fields
        self.customType = customType
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    func fieldSummary() -> String {
        guard let first = fields.first else { return "" }
        if first.isSecret {
            return "••••••••"
        }
        return first.value.prefix(30).description
    }
}