import SwiftUI

enum DetailTab: String, Hashable {
    case episodes, similar
}

@MainActor
@Observable
final class DetailModel {
    var tab: DetailTab = .episodes
    var seasonNumber: Int = 1
    var loadingEpisodes = false
    private var requested = false

    func prepare(app: AppModel, mediaID: String) async {
        guard !requested else { return }
        requested = true
        if let series = app.catalog.seriesDetail(id: mediaID) {
            seasonNumber = series.seasons.first?.number ?? 1
            if series.seasons.isEmpty {
                loadingEpisodes = true
                await app.ensureEpisodes(seriesID: mediaID)
                loadingEpisodes = false
                if let refreshed = app.catalog.seriesDetail(id: mediaID) {
                    seasonNumber = refreshed.seasons.first?.number ?? 1
                }
            }
        } else {
            tab = .similar
        }
    }
}

struct DetailView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let mediaID: String
    @State private var model = DetailModel()

    private var item: MediaItem? { app.catalog.media(id: mediaID) }
    private var series: SeriesDetail? { app.catalog.seriesDetail(id: mediaID) }

    var body: some View {
        LaylScreen {
            if let item {
                detail(item)
            } else {
                EmptyPane(title: Copy.noResults, message: Copy.noResultsBody)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task(id: mediaID) { await model.prepare(app: app, mediaID: mediaID) }
    }

    private func detail(_ item: MediaItem) -> some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    hero(item)
                    VStack(alignment: .leading, spacing: 14) {
                        Text(item.title)
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                        meta(item)
                        WhiteActionButton(title: Copy.play, systemImage: "play.fill") {
                            app.play(item)
                        }
                        .environment(\.layoutDirection, .leftToRight)
                        if series != nil {
                            DarkActionButton(title: Copy.downloadSeason, systemImage: "arrow.down") {
                                downloadSeason()
                            }
                            .environment(\.layoutDirection, .leftToRight)
                        } else if item.kind == .movie {
                            DarkActionButton(title: Copy.download, systemImage: "arrow.down") {
                                app.download(item)
                            }
                            .environment(\.layoutDirection, .leftToRight)
                        }
                        Text(item.overview)
                            .font(.system(size: 15))
                            .foregroundStyle(LaylColor.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                        if item.isDemo, let credit = item.credit {
                            Text(credit)
                                .font(.system(size: 11))
                                .foregroundStyle(LaylColor.tertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        reactions(item)
                        if series != nil {
                            tabs
                            if model.tab == .episodes {
                                episodeList
                            } else {
                                similarGrid(item)
                            }
                        } else {
                            SectionTitle(title: Copy.moreLikeThis)
                            similarGrid(item)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                    .frame(maxWidth: 860)
                    .frame(maxWidth: .infinity)
                }
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(edges: .top)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel(Copy.close)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    private func hero(_ item: MediaItem) -> some View {
        Artwork(asset: item.backdropAsset ?? item.posterAsset, url: item.backdropURL ?? item.posterURL)
            .frame(maxWidth: .infinity)
            .frame(height: 390)
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [.clear, LaylColor.backgroundDeep], startPoint: .center, endPoint: .bottom)
                    .frame(height: 160)
            }
            .clipped()
    }

    private func meta(_ item: MediaItem) -> some View {
        HStack(spacing: 8) {
            if let year = item.year {
                Text(String(year))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(LaylColor.secondary)
            }
            if let rating = item.rating {
                RatingBadge(text: rating, prominent: true)
            }
            if let quality = item.quality {
                RatingBadge(text: quality)
            }
            Spacer(minLength: 0)
        }
    }

    private func reactions(_ item: MediaItem) -> some View {
        let current = app.reaction(for: item.id)
        return HStack(spacing: 10) {
            HStack(spacing: 0) {
                ForEach(Reaction.allCases) { reaction in
                    Button {
                        app.setReaction(reaction, mediaID: item.id)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: reaction.symbol)
                                .font(.system(size: 16, weight: .semibold))
                            Text(reaction.title)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        .foregroundStyle(current == reaction ? .white : LaylColor.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            if current == reaction {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.white.opacity(0.12))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            if series != nil {
                Button {
                    downloadSeason()
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 16, weight: .semibold))
                        Text(Copy.download)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                }
                .buttonStyle(.glass)
                .accessibilityLabel(Copy.downloadSeason)
            }
        }
    }

    private var tabs: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 22) {
                tabButton(.episodes, title: Copy.episodes)
                tabButton(.similar, title: Copy.moreLikeThis)
                Spacer(minLength: 0)
            }
            if let series, series.seasons.count > 1 {
                Menu {
                    ForEach(series.seasons) { season in
                        Button("\(Copy.season) \(season.number)") { model.seasonNumber = season.number }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("\(Copy.season) \(model.seasonNumber)")
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.glass)
                .padding(.top, 12)
            }
        }
        .padding(.top, 4)
    }

    private func tabButton(_ tab: DetailTab, title: String) -> some View {
        Button {
            model.tab = tab
        } label: {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 16, weight: model.tab == tab ? .bold : .medium))
                    .foregroundStyle(model.tab == tab ? .white : LaylColor.tertiary)
                Rectangle()
                    .fill(model.tab == tab ? Color.white : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var episodeList: some View {
        if model.loadingEpisodes {
            ProgressView()
                .tint(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        } else if let series {
            let season = series.seasons.first { $0.number == model.seasonNumber } ?? series.seasons.first
            if let season, !season.episodes.isEmpty {
                VStack(spacing: 14) {
                    ForEach(season.episodes) { episode in
                        Button {
                            app.play(episode: episode, series: series)
                        } label: {
                            HStack(spacing: 12) {
                                Artwork(asset: episode.stillAsset ?? series.item.posterAsset, url: episode.stillURL ?? series.item.posterURL)
                                    .frame(width: 118, height: 68)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(episode.number). \(episode.title)")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Text("\(episode.durationMinutes) \(Copy.minute)")
                                        .font(.system(size: 13))
                                        .foregroundStyle(LaylColor.secondary)
                                }
                                Spacer(minLength: 8)
                                Text("\(Copy.season) \(episode.seasonNumber)")
                                    .font(.system(size: 13))
                                    .foregroundStyle(LaylColor.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(Copy.download, systemImage: "arrow.down") {
                                app.download(episode: episode, series: series)
                            }
                        }
                    }
                }
            } else {
                Text(Copy.noEpisodes)
                    .foregroundStyle(LaylColor.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func similarGrid(_ item: MediaItem) -> some View {
        let items = app.similar(to: item)
        return Group {
            if items.isEmpty {
                Text(Copy.similarEmpty)
                    .foregroundStyle(LaylColor.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 112, maximum: 180), spacing: 12)], spacing: 16) {
                    ForEach(items) { similar in
                        NavigationLink(value: Route.detail(similar.id)) {
                            PosterCard(item: similar, width: 112)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func downloadSeason() {
        guard let series else { return }
        let season = series.seasons.first { $0.number == model.seasonNumber } ?? series.seasons.first
        if let season {
            app.downloadSeason(series, season: season)
        }
    }
}
