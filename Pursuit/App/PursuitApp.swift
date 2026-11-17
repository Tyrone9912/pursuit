import SwiftUI
import SwiftData

@main
struct PursuitApp: App {
    let container: ModelContainer
    @StateObject private var viewModel: AppViewModel

    init() {
        let schema = Schema([Application.self, GeneratedContent.self, Profile.self])
        let builtContainer: ModelContainer
        do {
            builtContainer = try ModelContainer(for: schema)
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }
        container = builtContainer
        _viewModel = StateObject(wrappedValue: AppViewModel(modelContext: builtContainer.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 980, minHeight: 640)
        }
        .modelContainer(container)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1160, height: 740)
    }
}
