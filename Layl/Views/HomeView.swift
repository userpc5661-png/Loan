import SwiftUI

@MainActor
@Observable
final class HomeModel {
    var chip: HomeChip?

    func toggle(_ chip: HomeChip) {
        guard chip != .categories else { return }
        self.chip = self.chip == chip ? nil : chip
    }

    func hero(in app: AppModel) -> MediaItem? {
        let catalog = app.catalog
        switch chip {
        case .movies:
            return catalog.movies.first
        case .series:
            return catalog.series.first?.item
        case .trending, .none, .categories:
            return catalog.seriesDetail(id: DemoCatalog.sintel)?.item
                ?? catalog.series.first?.item
                ?? catalog.movies.first
        }
    }

    func exclusive(in app: AppModel) -> [MediaItem] {
        guard chip == nil || chip == .trending else { return [] }
        return DemoCatalog.exclusiveIDs.compactMap { app.catalog.movie(id: $0) }
    }

    func movies(in app: AppModel) -> [MediaItem] {
        guard chip != .series else { return [] }
        return Array(app.catalog.movies.prefix(20))
    }

    func series(in app: AppModel) -> [MediaItem] {
        guard chip != .movies else { return [] }
        return Array(app.catalog.series.map(\.item).prefix(20))
    }
}

struct HomeView: View {
    @Environment(AppModel.self) private var app
    @Binding var path: [Route]
    @State private var model = HomeModel()
    @State private var width: CGFloat = 390

    private var margin: CGFloat { width >= 700 ? 28 : 16 }

    var body: some View {
        LaylScreen {
            VStack(spacing: 8) {
                header
                    .padding(.horizontal, margin)
                    .padding(.top, 4)
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        chips
                        if app.catalog.isEmpty {
                            EmptyPane(title: Copy.emptyHome, message: Copy.emptyHomeBody, actionTitle: Copy.addPlaylist) {
                                path.append(.playlists)
                            }
                            .padding(.top, 40)
                        } else if let hero = model.hero(in: app) {
                            heroCard(hero)
                            exclusiveRail
                            continueRail
                            if !model.series(in: app).isEmpty {
                                posterRail(title: Copy.series, items: model.series(in: app))
                            }
                            if !model.movies(in: app).isEmpty {
                                posterRail(title: Copy.movies, items: model.movies(in: app))
                            }
                            liveRail
                        }
                    }
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
                .refreshable { await app.refreshAll() }
            }
        }
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { width = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, new in width = new }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(LaylColor.lilac)
                Text(Copy.home)
                    .font(.system(size: 22, weight: .bold))
            }
            Spacer(minLength: 8)
            HStack(spacing: 0) {
                AirPlayButton()
                    .frame(width: 36, height: 40)
                    .accessibilityLabel(Copy.airplay)
                IconHitButton(systemImage: "arrow.down.to.line", label: Copy.downloads) {
                    path.append(.downloads)
                }
                IconHitButton(systemImage: "bell", label: Copy.notifications, badge: app.unreadNotifications) {
                    app.unreadNotifications = false
                    path.append(.notifications)
                }
            }
            .environment(\.layoutDirection, .leftToRight)
        }
    }

    private var chips: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 8) {
                    ForEach([HomeChip.series, .trending, .movies, .categories]) { chip in
                        Button {
                            if chip == .categories {
                                path.append(.category(""))
                            } else {
                                model.toggle(chip)
                            }
                        } label: {
                            Text(chip.title)
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 14)
                                .frame(height: 36)
                        }
                        .buttonStyle(.glass(.regular.tint(model.chip == chip ? Color.white.opacity(0.22) : Color.clear)))
                    }
                }
            }
            .padding(.horizontal, margin)
        }
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: model.chip)
    }

    private func heroCard(_ item: MediaItem) -> some View {
        let cardWidth = min(max(width - margin * 2, 240), 860)
        let height = min(cardWidth * 1.28, 640)
        return ZStack(alignment: .bottom) {
            NavigationLink(value: Route.detail(item.id)) {
                ZStack(alignment: .bottom) {
                    Artwork(asset: item.posterAsset, url: item.posterURL)
                        .frame(maxWidth: .infinity)
                        .frame(height: height)
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.38),
                            .init(color: .black.opacity(0.18), location: 0.58),
                            .init(color: .black.opacity(0.92), location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    VStack(spacing: 8) {
                        Text(item.title)
                            .font(.system(size: width < 360 ? 34 : 42, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.45), radius: 8, y: 3)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(item.genreLine)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.88))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(.bottom, 78)
                    .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.plain)

            ViewThatFits(in: .horizontal) {
                heroButtons(item)
                VStack(spacing: 8) { heroButtons(item) }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
            .environment(\.layoutDirection, .leftToRight)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: LaylMetrics.heroRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LaylMetrics.heroRadius, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 0.6)
        }
        .shadow(color: LaylColor.purple.opacity(0.28), radius: 28, y: 16)
        .padding(.horizontal, margin)
    }

    private func heroButtons(_ item: MediaItem) -> some View {
        HStack(spacing: 10) {
            WhiteActionButton(title: Copy.play, systemImage: "play.fill") {
                app.play(item)
            }
            GlassLabelButton(
                title: Copy.myList,
                systemImage: app.isFavorite(item.id) ? "checkmark" : "plus"
            ) {
                app.toggleFavorite(item)
            }
        }
    }

    @ViewBuilder
    private var exclusiveRail: some View {
        let items = model.exclusive(in: app)
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: Copy.exclusive)
                    .padding(.horizontal, margin)
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(items) { item in
                            NavigationLink(value: Route.detail(item.id)) {
                                Artwork(asset: item.posterAsset, url: item.posterURL)
                                    .frame(width: width >= 700 ? 230 : 164, height: width >= 700 ? 142 : 104)
                                    .clipShape(RoundedRectangle(cornerRadius: LaylMetrics.thumbRadius, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, margin)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    @ViewBuilder
    private var continueRail: some View {
        let entries = app.continueWatching()
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: Copy.continueWatching)
                    .padding(.horizontal, margin)
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(entries) { entry in
                            Button {
                                app.resume(entry)
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Artwork(asset: entry.posterAsset.isEmpty ? nil : entry.posterAsset, url: entry.posterURL.isEmpty ? nil : entry.posterURL)
                                        .frame(width: width >= 700 ? 210 : 150, height: width >= 700 ? 118 : 86)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .overlay(alignment: .bottom) {
                                            WatchBar(fraction: entry.fraction)
                                                .padding(8)
                                        }
                                    Text(entry.title)
                                        .font(.system(size: 13, weight: .semibold))
                                        .lineLimit(1)
                                        .frame(width: width >= 700 ? 210 : 150, alignment: .leading)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, margin)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private func posterRail(title: String, items: [MediaItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: title)
                .padding(.horizontal, margin)
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(items) { item in
                        NavigationLink(value: Route.detail(item.id)) {
                            PosterCard(item: item, width: width >= 700 ? 156 : 118, progress: progress(for: item.id))
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(Copy.play, systemImage: "play.fill") { app.play(item) }
                            Button(app.isFavorite(item.id) ? Copy.removeFromList : Copy.myList, systemImage: "plus") {
                                app.toggleFavorite(item)
                            }
                            if item.kind == .movie {
                                Button(Copy.download, systemImage: "arrow.down") { app.download(item) }
                            }
                        }
                    }
                }
                .padding(.horizontal, margin)
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder
    private var liveRail: some View {
        let channels = Array(app.catalog.channels.prefix(10))
        if !channels.isEmpty, model.chip == nil || model.chip == .trending {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionTitle(title: Copy.live)
                    Spacer()
                    Button(Copy.all) { path.append(.live) }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LaylColor.lilac)
                }
                .padding(.horizontal, margin)
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(channels) { channel in
                            Button {
                                path.append(.channel(channel.id))
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(LaylColor.card)
                                        Artwork(asset: channel.logoAsset, url: channel.logoURL, system: "tv")
                                            .padding(18)
                                    }
                                    .frame(width: 112, height: 84)
                                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    Text(channel.name)
                                        .font(.system(size: 12, weight: .semibold))
                                        .lineLimit(1)
                                        .frame(width: 112, alignment: .leading)
                                    Text(channel.currentProgram()?.title ?? Copy.liveBadge)
                                        .font(.system(size: 11))
                                        .foregroundStyle(LaylColor.secondary)
                                        .lineLimit(1)
                                        .frame(width: 112, alignment: .leading)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, margin)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private func progress(for id: String) -> Double? {
        app.continueWatching().first { $0.mediaID == id }?.fraction
    }
}
