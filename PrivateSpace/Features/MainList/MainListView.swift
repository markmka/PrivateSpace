import SwiftUI
import SwiftData

struct MainListView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = MainListViewModel()
    @Query(sort: \VaultItem.modifiedAt, order: .reverse) private var items: [VaultItem]
    @Query private var customTypes: [CustomItemType]

    var filteredItems: [VaultItem] {
        var result = items

        if let type = viewModel.selectedType {
            result = result.filter { $0.type == type }
        }

        if !viewModel.searchText.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(viewModel.searchText) }
        }

        return result
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Nav bar
                HStack {
                    Text("Vault")
                        .font(.title2)
                        .fontWeight(.bold)

                    Spacer()

                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.body)
                    }
                }
                .padding(.horizontal, AppSpacing.standardPadding)
                .padding(.vertical, 12)

                // Filter pills
                FilterPillsView(selectedType: $viewModel.selectedType, customTypes: customTypes)
                    .padding(.bottom, 12)

                // Item list
                if filteredItems.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("暂无条目")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("点击右下角 + 添加第一个条目")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filteredItems) { item in
                            NavigationLink {
                                ItemDetailView(item: item)
                            } label: {
                                ItemRowView(item: item)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                        .onDelete(perform: deleteItems)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }

            // FAB
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FABMenuView(
                        isExpanded: $viewModel.isFABExpanded,
                        onSelectType: { type in
                            viewModel.createNewItem(type: type)
                        },
                        customTypes: customTypes
                    )
                }
            }
        }
        .navigationDestination(isPresented: $viewModel.showingNewItem) {
            ItemEditView(mode: .create(type: viewModel.selectedItemType))
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let item = filteredItems[index]
            modelContext.delete(item)
        }
    }
}

struct ItemRowView: View {
    let item: VaultItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.type.iconName)
                .font(.title3)
                .foregroundColor(ItemTypeMetadata.color(for: item.type))
                .frame(width: 40, height: 40)
                .background(ItemTypeMetadata.backgroundColor(for: item.type))
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.iconCornerRadius))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title.isEmpty ? "无标题" : item.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Text(item.fieldSummary())
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
