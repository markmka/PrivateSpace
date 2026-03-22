import SwiftUI
import SwiftData

@main
struct PrivateSpaceApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            VaultItem.self,
            CustomField.self,
            CustomItemType.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    if newPhase == .background {
                        appState.lock()
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
