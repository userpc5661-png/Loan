import SwiftData
import SwiftUI

@main
struct LaylApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let container: ModelContainer
    @State private var appModel: AppModel

    init() {
        UserDefaults.standard.set(["ar"], forKey: "AppleLanguages")
        UserDefaults.standard.set("ar", forKey: "AppleLocale")
        let container = LaylApp.makeContainer()
        self.container = container
        _appModel = State(initialValue: AppModel(container: container))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
                .modelContainer(container)
                .preferredColorScheme(.dark)
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "ar"))
                .tint(LaylColor.lilac)
        }
    }

    private static func makeContainer() -> ModelContainer {
        let stored = ModelConfiguration("Layl")
        do {
            return try ModelContainer(
                for: PlaylistRecord.self,
                FavoriteRecord.self,
                WatchProgressRecord.self,
                DownloadRecord.self,
                ReactionRecord.self,
                ProfileRecord.self,
                configurations: stored
            )
        } catch {
            let memory = ModelConfiguration(isStoredInMemoryOnly: true)
            return try! ModelContainer(
                for: PlaylistRecord.self,
                FavoriteRecord.self,
                WatchProgressRecord.self,
                DownloadRecord.self,
                ReactionRecord.self,
                ProfileRecord.self,
                configurations: memory
            )
        }
    }
}
