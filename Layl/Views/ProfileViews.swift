import SwiftUI

struct ProfileView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        LaylScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(Copy.account)
                        .font(.system(size: 32, weight: .bold))
                        .padding(.horizontal, 16)
                    profiles
                    VStack(spacing: 10) {
                        link(.myList, title: Copy.myList, system: "plus.rectangle.on.rectangle")
                        link(.downloads, title: Copy.downloads, system: "arrow.down.circle")
                        link(.live, title: Copy.live, system: "tv")
                        link(.playlists, title: Copy.addPlaylist, system: "list.bullet.rectangle")
                        link(.notifications, title: Copy.notifications, system: "bell")
                        link(.settings, title: Copy.settings, system: "gearshape")
                        link(.about, title: Copy.about, system: "info.circle")
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var profiles: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Copy.profiles)
                .font(.headline)
                .padding(.horizontal, 16)
            ScrollView(.horizontal) {
                HStack(spacing: 16) {
                    ForEach(app.profiles) { profile in
                        Button {
                            app.select(profile: profile)
                        } label: {
                            VStack(spacing: 8) {
                                profileAvatar(profile)
                                    .frame(width: 74, height: 74)
                                    .clipShape(Circle())
                                    .overlay {
                                        Circle().stroke(app.activeProfileID == profile.id ? Color.white : Color.clear, lineWidth: 2)
                                    }
                                Text(profile.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(app.activeProfileID == profile.id ? .white : LaylColor.secondary)
                                if profile.isKids {
                                    Text(Copy.kids)
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(LaylColor.purple, in: Capsule())
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder
    private func profileAvatar(_ profile: Profile) -> some View {
        if let symbol = profile.symbol {
            ZStack {
                LaylColor.purpleDeep
                Image(systemName: symbol)
                    .font(.title2)
            }
        } else {
            Artwork(asset: profile.avatarAsset, url: nil, system: "person.fill")
        }
    }

    private func link(_ route: Route, title: String, system: String) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: 12) {
                Image(systemName: system)
                    .frame(width: 28)
                    .foregroundStyle(LaylColor.lilac)
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LaylColor.tertiary)
                    .flipsForRightToLeftLayoutDirection(false)
            }
            .padding(.horizontal, 14)
            .frame(height: 54)
            .background(LaylColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct MyListView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        LaylScreen {
            let items = app.favorites()
            if items.isEmpty {
                EmptyPane(title: "قائمتك فارغة", message: "أضف أفلاماً ومسلسلات من زر قائمتي في صفحة العنوان.")
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 112, maximum: 180), spacing: 12)], spacing: 16) {
                        ForEach(items) { item in
                            NavigationLink(value: Route.detail(item.id)) {
                                PosterCard(item: item, width: 120)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle(Copy.myList)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DownloadsView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        LaylScreen {
            if app.downloads.items.isEmpty {
                EmptyPane(title: "لا توجد تنزيلات", message: "نزّل فيلماً أو موسماً لمشاهدته لاحقاً بدون اتصال.")
            } else {
                List {
                    ForEach(app.downloads.items) { item in
                        HStack(spacing: 12) {
                            Artwork(asset: item.posterAsset.isEmpty ? nil : item.posterAsset, url: item.posterURL.isEmpty ? nil : item.posterURL)
                                .frame(width: 56, height: 76)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.title).font(.system(size: 15, weight: .semibold)).lineLimit(2)
                                Text(status(item))
                                    .font(.system(size: 12))
                                    .foregroundStyle(LaylColor.secondary)
                                if item.state == .downloading {
                                    WatchBar(fraction: item.progress)
                                }
                            }
                            Spacer()
                            if item.state == .finished {
                                Button(Copy.play) {
                                    if let url = app.downloads.localURL(for: item.mediaID) {
                                        app.playerRequest = PlayerRequest(item: PlayableItem(
                                            mediaID: item.mediaID,
                                            title: item.title,
                                            subtitle: Copy.downloads,
                                            url: url,
                                            isLive: false,
                                            posterAsset: item.posterAsset.isEmpty ? nil : item.posterAsset,
                                            posterURL: item.posterURL.isEmpty ? nil : item.posterURL,
                                            seriesID: nil,
                                            seasonNumber: nil,
                                            episodeNumber: nil
                                        ))
                                    }
                                }
                                .buttonStyle(.glass)
                            } else if item.state == .downloading {
                                Button(Copy.cancel) { app.downloads.cancel(mediaID: item.mediaID) }
                                    .buttonStyle(.glass)
                            }
                        }
                        .listRowBackground(Color.clear)
                        .swipeActions {
                            Button(Copy.delete, role: .destructive) {
                                app.downloads.remove(mediaID: item.mediaID)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle(Copy.downloads)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func status(_ item: DownloadItem) -> String {
        switch item.state {
        case .queued: Copy.queued
        case .downloading: "\(Copy.downloading) \(Int(item.progress * 100))%"
        case .finished: Copy.finished
        case .failed: item.errorMessage.isEmpty ? Copy.failed : item.errorMessage
        }
    }
}

struct SettingsView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var app = app
        return LaylScreen {
            Form {
                Section("التشغيل") {
                    Picker(Copy.quality, selection: $app.quality) {
                        ForEach(PlaybackQuality.allCases) { quality in
                            Text(quality.title).tag(quality)
                        }
                    }
                    Toggle(Copy.autoplay, isOn: $app.autoplayNext)
                }
                Section("المحتوى") {
                    Toggle(Copy.showDemo, isOn: $app.showDemo)
                    Button(Copy.clearProgress, role: .destructive) { app.clearProgress() }
                }
                Section {
                    Button(Copy.replayIntro) { app.didFinishOnboarding = false }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(Copy.settings)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NotificationsView: View {
    @Environment(AppModel.self) private var app

    private let notices: [(String, String, String)] = [
        ("حلقة جديدة", "المواجهة أُضيفت إلى سينتل.", "اليوم"),
        ("قائمة محدّثة", "حصرياً على ليل: ثلاثة عناوين جديدة.", "أمس"),
        ("تنزيل مكتمل", "سيظهر هنا تقدم التنزيل عندما يبدأ.", "هذا الأسبوع")
    ]

    var body: some View {
        LaylScreen {
            List {
                ForEach(Array(notices.enumerated()), id: \.offset) { _, notice in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(notice.0).font(.system(size: 16, weight: .semibold))
                        Text(notice.1).font(.system(size: 14)).foregroundStyle(LaylColor.secondary)
                        Text(notice.2).font(.system(size: 12)).foregroundStyle(LaylColor.tertiary)
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .onAppear { app.unreadNotifications = false }
        }
        .navigationTitle(Copy.notifications)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AboutView: View {
    var body: some View {
        LaylScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        Image(systemName: "moon.fill").foregroundStyle(LaylColor.lilac).font(.largeTitle)
                        Text(Copy.brand).font(.largeTitle.weight(.bold))
                    }
                    Text("مشغّل IPTV بواجهة عربية داكنة، مبني بـ SwiftUI و Liquid Glass.")
                        .foregroundStyle(LaylColor.secondary)
                    Text(Copy.version + " 1.0")
                        .font(.footnote)
                        .foregroundStyle(LaylColor.tertiary)
                    Text(DemoCatalog.credit)
                        .font(.system(size: 14))
                        .foregroundStyle(LaylColor.secondary)
                    Text("لا يتضمن التطبيق أي بث محمي. القوائم التي تضيفها تبقى على جهازك.")
                        .font(.system(size: 14))
                        .foregroundStyle(LaylColor.secondary)
                }
                .padding(20)
                .frame(maxWidth: 720, alignment: .leading)
            }
        }
        .navigationTitle(Copy.about)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CategoryGridView: View {
    @Environment(AppModel.self) private var app
    let category: String

    var body: some View {
        LaylScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if category.isEmpty {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                            ForEach(app.catalog.categories, id: \.self) { name in
                                NavigationLink(value: Route.category(name)) {
                                    ZStack(alignment: .bottomLeading) {
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(LinearGradient(colors: [LaylColor.purpleDeep, LaylColor.background], startPoint: .topLeading, endPoint: .bottomTrailing))
                                            .frame(height: 96)
                                        Text(name)
                                            .font(.system(size: 18, weight: .bold))
                                            .padding(14)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else {
                        let items = app.catalog.movies.filter { $0.category == category } + app.catalog.series.map(\.item).filter { $0.category == category }
                        if items.isEmpty {
                            EmptyPane(title: Copy.noResults, message: Copy.noResultsBody)
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 112, maximum: 180), spacing: 12)], spacing: 16) {
                                ForEach(items) { item in
                                    NavigationLink(value: Route.detail(item.id)) {
                                        PosterCard(item: item, width: 120)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(category.isEmpty ? Copy.categories : category)
        .navigationBarTitleDisplayMode(.inline)
    }
}
