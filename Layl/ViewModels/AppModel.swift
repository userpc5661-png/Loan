import Foundation
import SwiftData

@MainActor
@Observable
final class AppModel {
    let library: LibraryStore
    let cache: CatalogCache
    let downloads: DownloadCenter

    private(set) var catalog = Catalog.empty
    private(set) var revision = 0
    private(set) var libraryTick = 0
    private(set) var playlists: [Playlist] = []
    private(set) var profiles: [Profile] = []
    private var playlistCatalogs: [UUID: Catalog] = [:]

    var activeProfileID: UUID = UUID() {
        didSet { defaults.set(activeProfileID.uuidString, forKey: Keys.profile) }
    }
    var showDemo: Bool = true {
        didSet { defaults.set(showDemo, forKey: Keys.demo); rebuild() }
    }
    var autoplayNext: Bool = true {
        didSet { defaults.set(autoplayNext, forKey: Keys.autoplay) }
    }
    var quality: PlaybackQuality = .auto {
        didSet { defaults.set(quality.rawValue, forKey: Keys.quality) }
    }
    var didFinishOnboarding: Bool = false {
        didSet { defaults.set(didFinishOnboarding, forKey: Keys.onboarding) }
    }
    var unreadNotifications: Bool = true {
        didSet { defaults.set(unreadNotifications, forKey: Keys.unread) }
    }
    var playerRequest: PlayerRequest?
    var alertMessage: String?
    var isSyncing = false
    var selectedTab: AppTab = .home
    var recentSearches: [String] = []

    private let defaults: UserDefaults

    init(container: ModelContainer, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        library = LibraryStore(container: container)
        cache = CatalogCache()
        downloads = .shared
        downloads.bind(library: library)
        profiles = library.profiles()
        playlists = library.playlists()
        if let raw = defaults.string(forKey: Keys.profile),
           let id = UUID(uuidString: raw),
           profiles.contains(where: { $0.id == id }) {
            activeProfileID = id
        } else {
            activeProfileID = profiles.first?.id ?? UUID()
        }
        showDemo = defaults.object(forKey: Keys.demo) as? Bool ?? true
        autoplayNext = defaults.object(forKey: Keys.autoplay) as? Bool ?? true
        quality = PlaybackQuality(rawValue: defaults.string(forKey: Keys.quality) ?? "") ?? .auto
        didFinishOnboarding = defaults.bool(forKey: Keys.onboarding)
        unreadNotifications = defaults.object(forKey: Keys.unread) as? Bool ?? true
        recentSearches = defaults.stringArray(forKey: Keys.recent) ?? []
        loadCachedCatalogs()
        rebuild()
    }

    var activeProfile: Profile? { profiles.first { $0.id == activeProfileID } }
    var isKids: Bool { activeProfile?.isKids == true }

    func rebuild() {
        var result = Catalog.empty
        if showDemo { result.merge(DemoCatalog.make()) }
        for stored in playlistCatalogs.values { result.merge(stored) }
        if isKids { result = result.kidsFiltered() }
        catalog = result
        revision += 1
    }

    func select(profile: Profile) {
        activeProfileID = profile.id
        profiles = library.profiles()
        rebuild()
        libraryTick += 1
    }

    func toggleFavorite(_ item: MediaItem) {
        _ = library.toggleFavorite(profile: activeProfileID, item: item)
        libraryTick += 1
    }

    func isFavorite(_ id: String) -> Bool {
        library.isFavorite(profile: activeProfileID, mediaID: id)
    }

    func favorites() -> [MediaItem] {
        library.favorites(profile: activeProfileID).compactMap { record in
            catalog.media(id: record.mediaID) ?? MediaItem(
                id: record.mediaID,
                kind: MediaKind(rawValue: record.kindRaw) ?? .movie,
                title: record.title,
                overview: "",
                year: nil,
                rating: nil,
                quality: nil,
                genres: [],
                posterAsset: record.posterAsset.isEmpty ? nil : record.posterAsset,
                posterURL: record.posterURL.isEmpty ? nil : record.posterURL,
                backdropAsset: nil,
                backdropURL: nil,
                streamURL: nil,
                durationMinutes: nil,
                category: nil,
                playlistID: nil,
                isDemo: false,
                credit: nil
            )
        }
    }

    func continueWatching() -> [ContinueEntry] {
        library.progressEntries(profile: activeProfileID)
    }

    func reaction(for mediaID: String) -> Reaction? {
        library.reaction(profile: activeProfileID, mediaID: mediaID)
    }

    func setReaction(_ reaction: Reaction?, mediaID: String) {
        let current = self.reaction(for: mediaID)
        library.setReaction(profile: activeProfileID, mediaID: mediaID, reaction: current == reaction ? nil : reaction)
        libraryTick += 1
    }

    func clearProgress() {
        library.clearProgress(profile: activeProfileID)
        libraryTick += 1
    }

    func search(_ query: String, scope: SearchScope) -> [SearchHit] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }
        var hits: [SearchHit] = []
        if scope == .all || scope == .movies {
            hits.append(contentsOf: catalog.movies.filter { matches($0, needle) }.map(SearchHit.media))
        }
        if scope == .all || scope == .series {
            hits.append(contentsOf: catalog.series.map(\.item).filter { matches($0, needle) }.map(SearchHit.media))
        }
        if scope == .all || scope == .live {
            hits.append(contentsOf: catalog.channels.filter { matchesChannel($0, needle) }.map(SearchHit.channel))
        }
        if scope == .all || scope == .clips {
            hits.append(contentsOf: catalog.clips.filter { $0.title.localizedCaseInsensitiveContains(needle) }.map(SearchHit.clip))
        }
        return hits
    }

    func rememberSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        recentSearches.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        recentSearches.insert(trimmed, at: 0)
        recentSearches = Array(recentSearches.prefix(8))
        defaults.set(recentSearches, forKey: Keys.recent)
    }

    func similar(to item: MediaItem) -> [MediaItem] {
        let genres = Set(item.genres)
        let pool = catalog.movies + catalog.series.map(\.item)
        let ranked = pool.filter { candidate in
            candidate.id != item.id && !genres.isDisjoint(with: Set(candidate.genres))
        }
        if ranked.isEmpty {
            return pool.filter { $0.id != item.id }.prefix(12).map { $0 }
        }
        return Array(ranked.prefix(12))
    }

    func play(_ item: MediaItem) {
        if item.kind == .series, let series = catalog.seriesDetail(id: item.id) {
            play(series: series)
            return
        }
        guard let url = resolvedURL(mediaID: item.id, remote: item.streamURL) else {
            alertMessage = "لا يوجد رابط تشغيل لهذا العنوان."
            return
        }
        playerRequest = PlayerRequest(item: PlayableItem(
            mediaID: item.id,
            title: item.title,
            subtitle: item.genreLine,
            url: url,
            isLive: false,
            posterAsset: item.posterAsset,
            posterURL: item.posterURL,
            seriesID: nil,
            seasonNumber: nil,
            episodeNumber: nil
        ))
    }

    func play(series: SeriesDetail) {
        let episode = series.seasons.sorted { $0.number < $1.number }.first?.episodes.sorted { $0.number < $1.number }.first
        guard let episode else {
            alertMessage = Copy.noEpisodes
            return
        }
        play(episode: episode, series: series)
    }

    func play(episode: Episode, series: SeriesDetail) {
        guard let url = resolvedURL(mediaID: episode.id, remote: episode.streamURL) else {
            alertMessage = "لا يوجد رابط تشغيل لهذه الحلقة."
            return
        }
        playerRequest = PlayerRequest(item: PlayableItem(
            mediaID: episode.id,
            title: episode.title,
            subtitle: "\(series.item.title) · \(Copy.season) \(episode.seasonNumber)",
            url: url,
            isLive: false,
            posterAsset: episode.stillAsset ?? series.item.posterAsset,
            posterURL: episode.stillURL ?? series.item.posterURL,
            seriesID: series.id,
            seasonNumber: episode.seasonNumber,
            episodeNumber: episode.number
        ))
    }

    func play(channel: LiveChannel) {
        guard let url = resolvedURL(mediaID: channel.id, remote: channel.streamURL) else {
            alertMessage = "هذه القناة بلا بث حالياً."
            return
        }
        let current = channel.currentProgram()?.title ?? Copy.live
        playerRequest = PlayerRequest(item: PlayableItem(
            mediaID: channel.id,
            title: channel.name,
            subtitle: current,
            url: url,
            isLive: true,
            posterAsset: channel.logoAsset,
            posterURL: channel.logoURL,
            seriesID: nil,
            seasonNumber: nil,
            episodeNumber: nil
        ))
    }

    func play(clip: ClipItem) {
        guard let url = resolvedURL(mediaID: clip.id, remote: clip.streamURL) else { return }
        playerRequest = PlayerRequest(item: PlayableItem(
            mediaID: clip.id,
            title: clip.title,
            subtitle: clip.creator,
            url: url,
            isLive: false,
            posterAsset: clip.posterAsset,
            posterURL: nil,
            seriesID: nil,
            seasonNumber: nil,
            episodeNumber: nil
        ))
    }

    func resume(_ entry: ContinueEntry) {
        guard let url = resolvedURL(mediaID: entry.mediaID, remote: entry.streamURL) else { return }
        playerRequest = PlayerRequest(item: PlayableItem(
            mediaID: entry.mediaID,
            title: entry.title,
            subtitle: entry.subtitle,
            url: url,
            isLive: false,
            posterAsset: entry.posterAsset.isEmpty ? nil : entry.posterAsset,
            posterURL: entry.posterURL.isEmpty ? nil : entry.posterURL,
            seriesID: entry.seriesID.isEmpty ? nil : entry.seriesID,
            seasonNumber: entry.seasonNumber == 0 ? nil : entry.seasonNumber,
            episodeNumber: entry.episodeNumber == 0 ? nil : entry.episodeNumber
        ))
    }

    func nextPlayable(after item: PlayableItem) -> PlayableItem? {
        guard autoplayNext, let seriesID = item.seriesID, let season = item.seasonNumber, let episode = item.episodeNumber,
              let series = catalog.seriesDetail(id: seriesID) else { return nil }
        let flat = series.seasons.sorted { $0.number < $1.number }.flatMap { $0.episodes.sorted { $0.number < $1.number } }
        guard let index = flat.firstIndex(where: { $0.seasonNumber == season && $0.number == episode }),
              flat.indices.contains(index + 1) else { return nil }
        let next = flat[index + 1]
        guard let url = resolvedURL(mediaID: next.id, remote: next.streamURL) else { return nil }
        return PlayableItem(
            mediaID: next.id,
            title: next.title,
            subtitle: "\(series.item.title) · \(Copy.season) \(next.seasonNumber)",
            url: url,
            isLive: false,
            posterAsset: next.stillAsset ?? series.item.posterAsset,
            posterURL: next.stillURL,
            seriesID: series.id,
            seasonNumber: next.seasonNumber,
            episodeNumber: next.number
        )
    }

    func saveWatchProgress(item: PlayableItem, position: Double, duration: Double) {
        guard !item.isLive, duration.isFinite, duration > 1, position.isFinite else { return }
        library.saveProgress(
            profile: activeProfileID,
            mediaID: item.mediaID,
            title: item.title,
            subtitle: item.subtitle,
            posterAsset: item.posterAsset ?? "",
            posterURL: item.posterURL ?? "",
            kind: item.seriesID == nil ? .movie : .episode,
            streamURL: item.url.isFileURL ? "" : item.url.absoluteString,
            position: position,
            duration: duration,
            seriesID: item.seriesID ?? "",
            seasonNumber: item.seasonNumber ?? 0,
            episodeNumber: item.episodeNumber ?? 0
        )
        libraryTick += 1
    }

    func download(_ item: MediaItem) {
        guard let remote = item.streamURL, let url = URL(string: remote) else {
            alertMessage = "لا يمكن تنزيل هذا العنوان."
            return
        }
        downloads.start(mediaID: item.id, title: item.title, posterAsset: item.posterAsset, posterURL: item.posterURL, remote: url)
    }

    func download(episode: Episode, series: SeriesDetail) {
        guard let remote = episode.streamURL, let url = URL(string: remote) else { return }
        downloads.start(
            mediaID: episode.id,
            title: "\(series.item.title) · \(episode.title)",
            posterAsset: episode.stillAsset ?? series.item.posterAsset,
            posterURL: episode.stillURL ?? series.item.posterURL,
            remote: url
        )
    }

    func downloadSeason(_ series: SeriesDetail, season: Season) {
        season.episodes.forEach { download(episode: $0, series: series) }
    }

    func ensureEpisodes(seriesID: String) async {
        guard let detail = catalog.seriesDetail(id: seriesID), detail.seasons.isEmpty,
              let parsed = Self.playlistKey(seriesID),
              let playlist = playlists.first(where: { $0.id == parsed.playlist }),
              playlist.kind == .xtream,
              let config = XtreamConfig.make(server: playlist.url, username: playlist.username, password: library.password(for: playlist))
        else { return }
        do {
            let seasons = try await XtreamClient.fetchEpisodes(config: config, seriesID: parsed.raw, playlistID: playlist.id)
            guard var stored = playlistCatalogs[playlist.id] else { return }
            stored.setSeasons(seasons, for: seriesID)
            playlistCatalogs[playlist.id] = stored
            cache.save(stored, playlistID: playlist.id)
            rebuild()
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func addM3U(name: String, urlString: String, epgURL: String) async {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme != nil else {
            alertMessage = LaylError.invalidURL.localizedDescription
            return
        }
        isSyncing = true
        defer { isSyncing = false }
        do {
            let text = try await fetchText(from: url)
            try commitM3U(name: name, text: text, source: trimmed, epgURL: epgURL)
        } catch {
            alertMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func addXtream(name: String, server: String, username: String, password: String) async {
        guard let config = XtreamConfig.make(server: server, username: username, password: password) else {
            alertMessage = LaylError.invalidURL.localizedDescription
            return
        }
        isSyncing = true
        defer { isSyncing = false }
        let playlist = library.upsertPlaylist(
            name: name.isEmpty ? server : name,
            kind: .xtream,
            url: config.server.absoluteString,
            username: username,
            password: password,
            epgURL: ""
        )
        do {
            let fetched = try await XtreamClient.fetchCatalog(config: config, playlistID: playlist.id)
            guard !fetched.isEmpty else {
                library.deletePlaylist(playlist.id)
                throw LaylError.emptyPlaylist
            }
            store(fetched, for: playlist)
            Task { await self.attachShortEPG(playlist: playlist, config: config) }
        } catch {
            library.deletePlaylist(playlist.id)
            reloadPlaylists()
            alertMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func importM3UFile(_ url: URL) async {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
                throw LaylError.emptyPlaylist
            }
            let destination = cache.importFolder().appendingPathComponent(UUID().uuidString + "-" + url.lastPathComponent)
            try? data.write(to: destination)
            try commitM3U(name: url.deletingPathExtension().lastPathComponent, text: text, source: destination.absoluteString, epgURL: "")
        } catch {
            alertMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func loadSamplePlaylist() {
        guard let url = Bundle.main.url(forResource: "SamplePlaylist", withExtension: "m3u"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            alertMessage = "تعذر فتح القائمة النموذجية داخل التطبيق."
            return
        }
        do {
            try commitM3U(name: "قائمة تجريبية", text: text, source: url.absoluteString, epgURL: "")
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func refreshAll() async {
        let current = playlists
        for playlist in current {
            await refresh(playlist)
        }
    }

    func refresh(_ playlist: Playlist) async {
        isSyncing = true
        defer { isSyncing = false }
        do {
            switch playlist.kind {
            case .m3u:
                guard let url = URL(string: playlist.url) else { throw LaylError.invalidURL }
                let text = try await fetchText(from: url)
                let parsed = M3UParser.parse(text, playlistID: playlist.id)
                guard !parsed.catalog.isEmpty else { throw LaylError.emptyPlaylist }
                library.markSynced(playlist.id, epgURL: parsed.epgURL)
                store(parsed.catalog, for: playlist, discoveredEPG: parsed.epgURL)
            case .xtream:
                let password = library.password(for: playlist)
                guard let config = XtreamConfig.make(server: playlist.url, username: playlist.username, password: password) else {
                    throw LaylError.invalidURL
                }
                let fetched = try await XtreamClient.fetchCatalog(config: config, playlistID: playlist.id)
                guard !fetched.isEmpty else { throw LaylError.emptyPlaylist }
                store(fetched, for: playlist)
                await attachShortEPG(playlist: playlist, config: config)
            }
        } catch {
            alertMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func deletePlaylist(_ playlist: Playlist) {
        library.deletePlaylist(playlist.id)
        cache.remove(playlistID: playlist.id)
        playlistCatalogs[playlist.id] = nil
        reloadPlaylists()
        rebuild()
    }

    func finishOnboarding() {
        didFinishOnboarding = true
    }

    static func playlistKey(_ mediaID: String) -> (playlist: UUID, kind: String, raw: String)? {
        let parts = mediaID.split(separator: ".", maxSplits: 3, omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 4, parts[0] == "pl", let id = UUID(uuidString: parts[1]) else { return nil }
        return (id, parts[2], parts[3])
    }

    private func commitM3U(name: String, text: String, source: String, epgURL: String) throws {
        let placeholder = UUID()
        let parsed = M3UParser.parse(text, playlistID: placeholder)
        guard !parsed.catalog.isEmpty else { throw LaylError.emptyPlaylist }
        let playlist = library.upsertPlaylist(
            name: name.isEmpty ? "قائمة M3U" : name,
            kind: .m3u,
            url: source,
            username: "",
            password: "",
            epgURL: epgURL.isEmpty ? (parsed.epgURL ?? "") : epgURL
        )
        let aligned = M3UParser.parse(text, playlistID: playlist.id)
        store(aligned.catalog, for: playlist, discoveredEPG: parsed.epgURL)
        if let epg = URL(string: playlist.epgURL), !playlist.epgURL.isEmpty {
            Task { await self.attachXMLTV(playlist: playlist, url: epg) }
        }
    }

    private func store(_ catalog: Catalog, for playlist: Playlist, discoveredEPG: String? = nil) {
        playlistCatalogs[playlist.id] = catalog
        cache.save(catalog, playlistID: playlist.id)
        library.markSynced(playlist.id, epgURL: discoveredEPG)
        reloadPlaylists()
        rebuild()
    }

    private func attachXMLTV(playlist: Playlist, url: URL) async {
        do {
            let data = try await fetchData(from: url, limit: 8_000_000)
            guard var stored = playlistCatalogs[playlist.id] else { return }
            stored.applyPrograms(XMLTVParser.parse(data))
            playlistCatalogs[playlist.id] = stored
            cache.save(stored, playlistID: playlist.id)
            rebuild()
        } catch {
            return
        }
    }

    private func attachShortEPG(playlist: Playlist, config: XtreamConfig) async {
        guard var stored = playlistCatalogs[playlist.id] else { return }
        var programs: [String: [EPGProgram]] = [:]
        for channel in stored.channels.prefix(12) {
            guard let raw = Self.playlistKey(channel.id)?.raw else { continue }
            if let list = try? await XtreamClient.fetchShortEPG(config: config, streamID: raw), !list.isEmpty {
                programs[channel.epgID ?? raw] = list
                programs[channel.id] = list
            }
        }
        guard !programs.isEmpty else { return }
        stored.applyPrograms(programs)
        playlistCatalogs[playlist.id] = stored
        cache.save(stored, playlistID: playlist.id)
        rebuild()
    }

    private func loadCachedCatalogs() {
        playlistCatalogs = [:]
        for playlist in playlists {
            if let cached = cache.load(playlistID: playlist.id) {
                playlistCatalogs[playlist.id] = cached
            }
        }
    }

    private func reloadPlaylists() {
        playlists = library.playlists()
    }

    private func resolvedURL(mediaID: String, remote: String?) -> URL? {
        if let local = downloads.localURL(for: mediaID) { return local }
        guard let remote, let url = URL(string: remote) else { return nil }
        return url
    }

    private func fetchText(from url: URL) async throws -> String {
        let data = try await fetchData(from: url, limit: 12_000_000)
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw LaylError.emptyPlaylist
        }
        return text
    }

    private func fetchData(from url: URL, limit: Int) async throws -> Data {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw LaylError.badResponse
            }
            if data.count > limit { return Data(data.prefix(limit)) }
            return data
        } catch let error as LaylError {
            throw error
        } catch {
            throw LaylError.network(error.localizedDescription)
        }
    }

    private func matches(_ item: MediaItem, _ needle: String) -> Bool {
        item.title.localizedCaseInsensitiveContains(needle)
            || item.overview.localizedCaseInsensitiveContains(needle)
            || item.genres.contains { $0.localizedCaseInsensitiveContains(needle) }
            || (item.category?.localizedCaseInsensitiveContains(needle) ?? false)
    }

    private func matchesChannel(_ channel: LiveChannel, _ needle: String) -> Bool {
        channel.name.localizedCaseInsensitiveContains(needle) || channel.category.localizedCaseInsensitiveContains(needle)
    }

    private enum Keys {
        static let demo = "layl.showDemo"
        static let autoplay = "layl.autoplay"
        static let quality = "layl.quality"
        static let onboarding = "layl.onboarding"
        static let profile = "layl.profile"
        static let unread = "layl.unread"
        static let recent = "layl.recentSearches"
    }
}

extension AppModel {
    static let preview: AppModel = {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: PlaylistRecord.self,
            FavoriteRecord.self,
            WatchProgressRecord.self,
            DownloadRecord.self,
            ReactionRecord.self,
            ProfileRecord.self,
            configurations: configuration
        )
        let defaults = UserDefaults(suiteName: "layl.preview") ?? .standard
        let model = AppModel(container: container, defaults: defaults)
        model.didFinishOnboarding = true
        return model
    }()
}
