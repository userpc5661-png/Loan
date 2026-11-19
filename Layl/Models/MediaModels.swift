import Foundation

enum MediaKind: String, Codable, Hashable, Sendable {
    case movie, series, episode, live, clip
}

enum PlaylistKind: String, Codable, Hashable, Sendable {
    case m3u, xtream
}

enum Reaction: String, Codable, CaseIterable, Identifiable, Sendable {
    case dislike, like, love
    var id: String { rawValue }

    var title: String {
        switch self {
        case .dislike: Copy.notForMe
        case .like: Copy.liked
        case .love: Copy.loved
        }
    }

    var symbol: String {
        switch self {
        case .dislike: "hand.thumbsdown"
        case .like: "hand.thumbsup"
        case .love: "heart"
        }
    }
}

enum PlaybackQuality: String, Codable, CaseIterable, Identifiable, Sendable {
    case auto, high, medium, low
    var id: String { rawValue }
    var title: String {
        switch self {
        case .auto: "تلقائي"
        case .high: "عالية"
        case .medium: "متوسطة"
        case .low: "منخفضة"
        }
    }

    var peakBitRate: Double {
        switch self {
        case .auto: 0
        case .high: 8_000_000
        case .medium: 2_000_000
        case .low: 800_000
        }
    }
}

enum HomeChip: String, CaseIterable, Identifiable, Hashable {
    case series, trending, movies, categories
    var id: String { rawValue }
    var title: String {
        switch self {
        case .series: Copy.series
        case .trending: Copy.trending
        case .movies: Copy.movies
        case .categories: Copy.categories
        }
    }
}

enum AppTab: String, Hashable, CaseIterable, Identifiable {
    case home, clips, search, profile
    var id: String { rawValue }
}

enum Route: Hashable {
    case detail(String)
    case live
    case category(String)
    case myList
    case downloads
    case settings
    case playlists
    case notifications
    case channel(String)
    case about
}

struct MediaItem: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var kind: MediaKind
    var title: String
    var overview: String
    var year: Int?
    var rating: String?
    var quality: String?
    var genres: [String]
    var posterAsset: String?
    var posterURL: String?
    var backdropAsset: String?
    var backdropURL: String?
    var streamURL: String?
    var durationMinutes: Int?
    var category: String?
    var playlistID: String?
    var isDemo: Bool
    var credit: String?

    var genreLine: String { genres.joined(separator: " • ") }
}

struct Episode: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var number: Int
    var seasonNumber: Int
    var title: String
    var overview: String
    var durationMinutes: Int
    var stillAsset: String?
    var stillURL: String?
    var streamURL: String?
}

struct Season: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var number: Int
    var title: String
    var episodes: [Episode]
}

struct SeriesDetail: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var item: MediaItem
    var seasons: [Season]
}

struct EPGProgram: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var title: String
    var start: Date
    var end: Date
    var overview: String

    func contains(_ date: Date) -> Bool {
        date >= start && date < end
    }
}

struct LiveChannel: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var name: String
    var number: Int
    var category: String
    var logoAsset: String?
    var logoURL: String?
    var streamURL: String?
    var epgID: String?
    var programs: [EPGProgram]
    var playlistID: String?
    var isDemo: Bool

    func currentProgram(at date: Date = .now) -> EPGProgram? {
        programs.first { $0.contains(date) }
    }

    func upcoming(at date: Date = .now, limit: Int = 4) -> [EPGProgram] {
        programs.filter { $0.end > date }.sorted { $0.start < $1.start }.prefix(limit).map { $0 }
    }
}

struct ClipItem: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var title: String
    var creator: String
    var overview: String
    var posterAsset: String?
    var streamURL: String?
    var isDemo: Bool
}

struct Catalog: Codable, Sendable, Equatable {
    var movies: [MediaItem]
    var series: [SeriesDetail]
    var channels: [LiveChannel]
    var clips: [ClipItem]

    static let empty = Catalog(movies: [], series: [], channels: [], clips: [])

    var isEmpty: Bool { movies.isEmpty && series.isEmpty && channels.isEmpty && clips.isEmpty }

    mutating func merge(_ other: Catalog) {
        absorb(other.movies, into: \.movies)
        absorbSeries(other.series)
        absorb(other.channels, into: \.channels)
        absorb(other.clips, into: \.clips)
    }

    private mutating func absorb<T: Identifiable>(_ items: [T], into keyPath: WritableKeyPath<Catalog, [T]>) where T.ID == String {
        var current = self[keyPath: keyPath]
        var seen = Set(current.map(\.id))
        for item in items where seen.insert(item.id).inserted {
            current.append(item)
        }
        self[keyPath: keyPath] = current
    }

    private mutating func absorbSeries(_ items: [SeriesDetail]) {
        var seen = Set(series.map(\.id))
        for item in items where seen.insert(item.id).inserted {
            series.append(item)
        }
    }

    func movie(id: String) -> MediaItem? { movies.first { $0.id == id } }
    func seriesDetail(id: String) -> SeriesDetail? { series.first { $0.id == id } }
    func channel(id: String) -> LiveChannel? { channels.first { $0.id == id } }
    func clip(id: String) -> ClipItem? { clips.first { $0.id == id } }

    func media(id: String) -> MediaItem? {
        if let movie = movie(id: id) { return movie }
        if let series = seriesDetail(id: id) { return series.item }
        return nil
    }

    mutating func applyPrograms(_ programs: [String: [EPGProgram]]) {
        for index in channels.indices {
            let keys = [channels[index].epgID, channels[index].id, channels[index].name].compactMap { $0 }
            if let match = keys.compactMap({ programs[$0] }).first, !match.isEmpty {
                channels[index].programs = match.sorted { $0.start < $1.start }
            }
        }
    }

    mutating func setSeasons(_ seasons: [Season], for seriesID: String) {
        guard let index = series.firstIndex(where: { $0.id == seriesID }) else { return }
        series[index].seasons = seasons
        if series[index].item.streamURL == nil {
            series[index].item.streamURL = seasons.first?.episodes.first?.streamURL
        }
    }

    func kidsFiltered() -> Catalog {
        func allowed(_ rating: String?) -> Bool {
            switch rating {
            case "18+", "16+", "13+": return false
            default: return true
            }
        }
        return Catalog(
            movies: movies.filter { allowed($0.rating) },
            series: series.filter { allowed($0.item.rating) },
            channels: channels.filter { $0.category != "رياضة" },
            clips: clips
        )
    }

    var categories: [String] {
        let names = movies.compactMap(\.category) + series.compactMap { $0.item.category } + channels.map(\.category)
        var seen = Set<String>()
        return names.filter { seen.insert($0).inserted }
    }
}

struct Playlist: Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var kind: PlaylistKind
    var url: String
    var username: String
    var epgURL: String
    var createdAt: Date
    var lastSyncedAt: Date?
}

struct Profile: Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var avatarAsset: String
    var symbol: String?
    var isKids: Bool
}

struct ContinueEntry: Identifiable, Hashable, Sendable {
    var id: String { mediaID }
    var mediaID: String
    var title: String
    var subtitle: String
    var posterAsset: String
    var posterURL: String
    var position: Double
    var duration: Double
    var streamURL: String
    var kind: MediaKind
    var seriesID: String
    var seasonNumber: Int
    var episodeNumber: Int

    var fraction: Double {
        guard duration > 1 else { return 0 }
        return min(max(position / duration, 0), 1)
    }
}

struct PlayableItem: Hashable, Sendable {
    var mediaID: String
    var title: String
    var subtitle: String
    var url: URL
    var isLive: Bool
    var posterAsset: String?
    var posterURL: String?
    var seriesID: String?
    var seasonNumber: Int?
    var episodeNumber: Int?
}

struct PlayerRequest: Identifiable {
    let id = UUID()
    let item: PlayableItem
}

enum SearchScope: String, CaseIterable, Identifiable {
    case all, movies, series, live, clips
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: Copy.all
        case .movies: Copy.movies
        case .series: Copy.series
        case .live: Copy.live
        case .clips: Copy.clips
        }
    }
}

enum SearchHit: Identifiable, Hashable {
    case media(MediaItem)
    case channel(LiveChannel)
    case clip(ClipItem)

    var id: String {
        switch self {
        case .media(let item): item.id
        case .channel(let channel): channel.id
        case .clip(let clip): clip.id
        }
    }
}

enum DownloadState: String, Codable, Sendable {
    case queued, downloading, finished, failed
}

struct DownloadItem: Identifiable, Hashable, Sendable {
    var id: String { mediaID }
    var mediaID: String
    var title: String
    var posterAsset: String
    var posterURL: String
    var remoteURL: String
    var localPath: String
    var bookmarkData: Data?
    var state: DownloadState
    var progress: Double
    var errorMessage: String
    var isHLS: Bool
}

enum LaylError: LocalizedError {
    case invalidURL
    case emptyPlaylist
    case unauthorized
    case badResponse
    case network(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "عنوان الرابط غير صالح."
        case .emptyPlaylist: "القائمة فارغة أو يتعذر قراءتها."
        case .unauthorized: "تعذر تسجيل الدخول. تحقق من اسم المستخدم وكلمة المرور."
        case .badResponse: "الخادم أعاد استجابة غير مفهومة."
        case .network(let message): "تعذر الاتصال: \(message)"
        }
    }
}

enum MediaText {
    static func year(from raw: String) -> Int? {
        let digits = raw.filter(\.isNumber)
        guard digits.count >= 4 else { return Int(digits) }
        return Int(digits.prefix(4))
    }

    static func minutes(from raw: String) -> Int {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return 0 }
        let parts = trimmed.split(separator: ":").compactMap { Int($0) }
        switch parts.count {
        case 3: return parts[0] * 60 + parts[1]
        case 2: return parts[0]
        case 1: return parts[0] > 300 ? parts[0] / 60 : parts[0]
        default: return 0
        }
    }

    static func decodeMaybeBase64(_ string: String) -> String {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 8, trimmed.count % 4 == 0,
              let data = Data(base64Encoded: trimmed),
              let decoded = String(data: data, encoding: .utf8),
              !decoded.isEmpty,
              decoded.contains(where: { $0.isLetter || $0.isWhitespace }) else {
            return string
        }
        return decoded
    }
}

enum PublicStreams {
    static let sintel = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4"
    static let bunny = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
    static let steel = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4"
    static let elephants = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4"
    static let appleAdvanced = "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8"
    static let appleBipBop = "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
    static let steelHLS = "https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8"
    static let muxBunny = "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"
}
