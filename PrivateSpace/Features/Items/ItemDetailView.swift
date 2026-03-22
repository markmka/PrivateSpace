import SwiftUI
import SwiftData

struct ItemDetailView: View {
    let item: VaultItem

    var body: some View {
        Text("Item Detail: \(item.title)")
            .navigationTitle("详情")
    }
}
