import Foundation
import SwiftData

struct PresetField: Codable, Identifiable {
    var id: UUID
    var name: String
    var isSecret: Bool

    init(id: UUID = UUID(), name: String, isSecret: Bool = false) {
        self.id = id
        self.name = name
        self.isSecret = isSecret
    }
}

@Model
final class CustomItemType {
    @Attribute(.unique) var id: UUID
    var name: String
    var iconName: String
    var presetFieldsData: Data  // Encoded [PresetField]
    var createdAt: Date

    var presetFields: [PresetField] {
        get {
            (try? JSONDecoder().decode([PresetField].self, from: presetFieldsData)) ?? []
        }
        set {
            guard let encoded = try? JSONEncoder().encode(newValue) else { return }
            presetFieldsData = encoded
        }
    }

    init(id: UUID = UUID(), name: String = "", iconName: String = "square.grid.2x2.fill", presetFields: [PresetField] = [], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.presetFieldsData = (try? JSONEncoder().encode(presetFields)) ?? Data()
        self.createdAt = createdAt
    }
}