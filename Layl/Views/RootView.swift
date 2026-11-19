import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var app = app
        Group {
            if app.didFinishOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .fullScreenCover(item: $app.playerRequest) { request in
            PlayerScreen(request: request)
        }
        .alert("ليل", isPresented: Binding(
            get: { app.alertMessage != nil },
            set: { if !$0 { app.alertMessage = nil } }
        )) {
            Button("حسناً", role: .cancel) {}
        } message: {
            Text(app.alertMessage ?? "")
        }
    }
}

struct MainTabView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var app = app
        TabView(selection: $app.selectedTab) {
            Tab(Copy.home, systemImage: "house.fill", value: AppTab.home) {
                HomeTab()
            }
            Tab(Copy.clips, systemImage: "play.rectangle.on.rectangle", value: AppTab.clips) {
                ClipsView()
            }
            Tab(Copy.search, systemImage: "magnifyingglass", value: AppTab.search) {
                SearchTab()
            }
            Tab(value: AppTab.profile) {
                ProfileTab()
            } label: {
                Label {
                    Text(Copy.account)
                } icon: {
                    Image("AvatarLayl")
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFill()
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewStyle(.sidebarAdaptable)
        .tint(.white)
    }
}

private struct HomeTab: View {
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(path: $path)
                .navigationDestination(for: Route.self) { route in
                    RouteScreen(route: route)
                }
        }
    }
}

private struct SearchTab: View {
    var body: some View {
        NavigationStack {
            SearchView()
                .navigationDestination(for: Route.self) { route in
                    RouteScreen(route: route)
                }
        }
    }
}

private struct ProfileTab: View {
    var body: some View {
        NavigationStack {
            ProfileView()
                .navigationDestination(for: Route.self) { route in
                    RouteScreen(route: route)
                }
        }
    }
}

struct RouteScreen: View {
    @Environment(AppModel.self) private var app
    let route: Route

    var body: some View {
        switch route {
        case .detail(let id):
            DetailView(mediaID: id)
        case .live:
            LiveTVView()
        case .category(let name):
            CategoryGridView(category: name)
        case .myList:
            MyListView()
        case .downloads:
            DownloadsView()
        case .settings:
            SettingsView()
        case .playlists:
            PlaylistsView()
        case .notifications:
            NotificationsView()
        case .channel(let id):
            ChannelDetailView(channelID: id)
        case .about:
            AboutView()
        }
    }
}
