import SwiftUI
import SwiftData
import Combine

@MainActor
final class MainListViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var selectedType: ItemType? = nil
    @Published var isFABExpanded: Bool = false
    @Published var showingNewItem: Bool = false
    @Published var selectedItemType: ItemType = .password

    func createNewItem(type: ItemType) {
        selectedItemType = type
        showingNewItem = true
    }
}
