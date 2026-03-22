import SwiftUI

enum ItemEditMode {
    case create(type: ItemType)
    case edit(item: VaultItem)
}

struct ItemEditView: View {
    let mode: ItemEditMode

    var body: some View {
        Text("Create/Edit Item")
            .navigationTitle(mode == .create(type: .password) ? "新建" : "编辑")
    }
}
