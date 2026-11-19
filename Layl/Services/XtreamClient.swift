import Foundation

struct FlexString: Codable, Hashable, Sendable {
    var value: String

    init(_ value: String) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = String(int)
        } else if let double = try? container.decode(Double.self) {
            value = String(Int(double))
        } else if container.decodeNil() {
            value = ""
        } else {
            value = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

struct XtreamConfig: Hashable, Sendable {
    var server: URL
    var username: String
    var password: String

    static func make(server raw: String, username: String, password: String) -> XtreamConfig? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if !text.lowercased().hasPrefix("http://") && !text.lowercased().hasPrefix("https://") {
            text = "http://" + text
        }
        while text.hasSuffix("/") { text.removeLast() }
        guard let server = URL(string: text) else { return nil }
        return XtreamConfig(server: server, username: username, password: password)
    }

    func apiURL(action: String? = nil, extra: [URLQueryItem] = []) -> URL? {
        guard var components = URLComponents(url: server, resolvingAgainstBaseURL: false) else { return nil }
        let base = components.path == "/" ? "" : components.path
        components.path = base + "/player_api.php"
        var items = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password)
        ]
        if let action { items.append(URLQueryItem(name: "action", value: action)) }
        items.append(contentsOf: extra)
        components.queryItems = items
        return components.url
    }

    func xmltvURL() -> URL? {
        guard var components = URLComponents(url: server, resolvingAgainstBaseURL: false) else { return nil }
        let base = components.path == "/" ? "" : components.path
        components.path = base + "/xmltv.php"
        components.queryItems = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password)
        ]
        return components.url
    }

    func streamURL(kind: String, id: String, ext: String) -> URL? {
        guard var components = URLComponents(url: server, resolvingAgainstBaseURL: false) else { return nil }
        let user = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username
        let pass = password.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? password
        let base = components.path == "/" ? "" : components.path
        let cleanExt = ext.isEmpty ? "mp4" : ext
        components.path = "\(base)/\(kind)/\(user)/\(pass)/\(id).\(cleanExt)"
        components.queryItems = nil
        return components.url
    }
}

enum XtreamClient {
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 35
        configuration.timeoutIntervalForResource = 60
        return URLSession(configuration: configuration)
    }()

    static func fetchCatalog(config: XtreamConfig, playlistID: UUID) async throws -> Catalog {
        try await authenticate(config: config)
        async let liveCategories = categories(config: config, action: "get_live_categories")
        async let vodCategories = categories(config: config, action: "get_vod_categories")
        async let seriesCategories = categories(config: config, action: "get_series_categories")
        async let liveStreams = live(config: config)
        async let vodStreams = vod(config: config)
        async let seriesList = series(config: config)

        let liveMap = try await liveCategories
        let vodMap = try await vodCategories
        let seriesMap = try await seriesCategories
        let liveRows = try await liveStreams
        let vodRows = try await vodStreams
        let seriesRows = try await seriesList
        let prefix = playlistID.uuidString

        let channels: [LiveChannel] = liveRows.enumerated().map { index, stream in
            LiveChannel(
                id: "pl.\(prefix).live.\(stream.streamID)",
                name: stream.name,
                number: index + 1,
                category: liveMap[stream.categoryID] ?? "عام",
                logoAsset: nil,
                logoURL: stream.icon.isEmpty ? nil : stream.icon,
                streamURL: config.streamURL(kind: "live", id: stream.streamID, ext: "m3u8")?.absoluteString,
                epgID: stream.epgChannelID.isEmpty ? stream.streamID : stream.epgChannelID,
                programs: [],
                playlistID: prefix,
                isDemo: false
            )
        }

        let movies: [MediaItem] = vodRows.map { stream in
            MediaItem(
                id: "pl.\(prefix).movie.\(stream.streamID)",
                kind: .movie,
                title: stream.name,
                overview: stream.plot,
                year: MediaText.year(from: stream.year),
                rating: stream.rating.isEmpty ? nil : stream.rating,
                quality: "HD",
                genres: splitGenres(stream.genre),
                posterAsset: nil,
                posterURL: stream.icon.isEmpty ? nil : stream.icon,
                backdropAsset: nil,
                backdropURL: nil,
                streamURL: config.streamURL(kind: "movie", id: stream.streamID, ext: stream.container)?.absoluteString,
                durationMinutes: nil,
                category: vodMap[stream.categoryID] ?? "أفلام",
                playlistID: prefix,
                isDemo: false,
                credit: nil
            )
        }

        let seriesDetails: [SeriesDetail] = seriesRows.map { show in
            let item = MediaItem(
                id: "pl.\(prefix).series.\(show.seriesID)",
                kind: .series,
                title: show.name,
                overview: show.plot,
                year: MediaText.year(from: show.releaseDate),
                rating: show.rating.isEmpty ? nil : show.rating,
                quality: "HD",
                genres: splitGenres(show.genre),
                posterAsset: nil,
                posterURL: show.cover.isEmpty ? nil : show.cover,
                backdropAsset: nil,
                backdropURL: show.backdrop.isEmpty ? nil : show.backdrop,
                streamURL: nil,
                durationMinutes: nil,
                category: seriesMap[show.categoryID] ?? "مسلسلات",
                playlistID: prefix,
                isDemo: false,
                credit: nil
            )
            return SeriesDetail(id: item.id, item: item, seasons: [])
        }

        return Catalog(movies: movies, series: seriesDetails, channels: channels, clips: [])
    }

    static func fetchEpisodes(config: XtreamConfig, seriesID: String, playlistID: UUID) async throws -> [Season] {
        guard let url = config.apiURL(action: "get_series_info", extra: [URLQueryItem(name: "series_id", value: seriesID)]) else {
            throw LaylError.invalidURL
        }
        let data = try await data(from: url)
        let response = try JSONDecoder().decode(XtreamSeriesInfo.self, from: data)
        let prefix = playlistID.uuidString
        return response.seasons.keys.compactMap { Int($0) }.sorted().map { number in
            let episodes = (response.seasons[String(number)] ?? []).enumerated().map { index, episode in
                let episodeNumber = Int(episode.episodeNum) ?? (index + 1)
                let ext = episode.container.isEmpty ? "mp4" : episode.container
                return Episode(
                    id: "pl.\(prefix).ep.\(episode.id)",
                    number: episodeNumber,
                    seasonNumber: number,
                    title: episode.title.isEmpty ? "الحلقة \(episodeNumber)" : episode.title,
                    overview: episode.plot,
                    durationMinutes: MediaText.minutes(from: episode.duration),
                    stillAsset: nil,
                    stillURL: episode.image.isEmpty ? nil : episode.image,
                    streamURL: config.streamURL(kind: "series", id: episode.id, ext: ext)?.absoluteString
                )
            }
            return Season(id: "pl.\(prefix).season.\(seriesID).\(number)", number: number, title: "\(Copy.season) \(number)", episodes: episodes)
        }
    }

    static func fetchShortEPG(config: XtreamConfig, streamID: String) async throws -> [EPGProgram] {
        guard let url = config.apiURL(
            action: "get_short_epg",
            extra: [
                URLQueryItem(name: "stream_id", value: streamID),
                URLQueryItem(name: "limit", value: "8")
            ]
        ) else { throw LaylError.invalidURL }
        let data = try await data(from: url)
        let response = try JSONDecoder().decode(XtreamEPGResponse.self, from: data)
        return response.epgListings.compactMap { listing in
            let start = date(fromTimestamp: listing.startTimestamp) ?? date(fromText: listing.start)
            let end = date(fromTimestamp: listing.stopTimestamp) ?? date(fromText: listing.end)
            guard let start, let end else { return nil }
            return EPGProgram(
                id: "\(streamID)-\(Int(start.timeIntervalSince1970))",
                title: MediaText.decodeMaybeBase64(listing.title),
                start: start,
                end: end,
                overview: MediaText.decodeMaybeBase64(listing.description)
            )
        }
    }

    private static func authenticate(config: XtreamConfig) async throws {
        guard let url = config.apiURL() else { throw LaylError.invalidURL }
        let data = try await data(from: url)
        let info = try? JSONDecoder().decode(XtreamAuth.self, from: data)
        let auth = info?.userInfo?.auth.value ?? ""
        let status = info?.userInfo?.status.lowercased() ?? ""
        guard auth == "1" || status == "active" else { throw LaylError.unauthorized }
    }

    private static func categories(config: XtreamConfig, action: String) async throws -> [String: String] {
        guard let url = config.apiURL(action: action) else { throw LaylError.invalidURL }
        let data = try await data(from: url)
        let rows = (try? JSONDecoder().decode([XtreamCategory].self, from: data)) ?? []
        var map: [String: String] = [:]
        for row in rows where !row.categoryID.value.isEmpty {
            map[row.categoryID.value] = row.categoryName
        }
        return map
    }

    private static func live(config: XtreamConfig) async throws -> [XtreamLive] {
        guard let url = config.apiURL(action: "get_live_streams") else { throw LaylError.invalidURL }
        let data = try await data(from: url)
        return (try? JSONDecoder().decode([XtreamLive].self, from: data)) ?? []
    }

    private static func vod(config: XtreamConfig) async throws -> [XtreamVOD] {
        guard let url = config.apiURL(action: "get_vod_streams") else { throw LaylError.invalidURL }
        let data = try await data(from: url)
        return (try? JSONDecoder().decode([XtreamVOD].self, from: data)) ?? []
    }

    private static func series(config: XtreamConfig) async throws -> [XtreamSeries] {
        guard let url = config.apiURL(action: "get_series") else { throw LaylError.invalidURL }
        let data = try await data(from: url)
        return (try? JSONDecoder().decode([XtreamSeries].self, from: data)) ?? []
    }

    private static func data(from url: URL) async throws -> Data {
        do {
            let (data, response) = try await session.data(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw LaylError.badResponse
            }
            return data
        } catch let error as LaylError {
            throw error
        } catch {
            throw LaylError.network(error.localizedDescription)
        }
    }

    private static func splitGenres(_ raw: String) -> [String] {
        raw.split { $0 == "," || $0 == "/" || $0 == "|" }.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private static func date(fromTimestamp raw: String) -> Date? {
        guard let seconds = TimeInterval(raw) else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    private static func date(fromText raw: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: raw)
    }
}

private struct XtreamAuth: Decodable {
    var userInfo: User?
    struct User: Decodable {
        var auth: FlexString
        var status: String
        enum CodingKeys: String, CodingKey { case auth, status }
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            auth = (try? container.decode(FlexString.self, forKey: .auth)) ?? FlexString("0")
            status = (try? container.decode(String.self, forKey: .status)) ?? ""
        }
    }
    enum CodingKeys: String, CodingKey { case userInfo = "user_info" }
}

private struct XtreamCategory: Decodable {
    var categoryID: FlexString
    var categoryName: String
    enum CodingKeys: String, CodingKey {
        case categoryID = "category_id"
        case categoryName = "category_name"
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        categoryID = (try? container.decode(FlexString.self, forKey: .categoryID)) ?? FlexString("")
        categoryName = (try? container.decode(String.self, forKey: .categoryName)) ?? ""
    }
}

private struct XtreamLive: Decodable {
    var name: String
    var streamID: String
    var icon: String
    var epgChannelID: String
    var categoryID: String
    enum CodingKeys: String, CodingKey {
        case name
        case streamID = "stream_id"
        case icon = "stream_icon"
        case epgChannelID = "epg_channel_id"
        case categoryID = "category_id"
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? container.decode(String.self, forKey: .name)) ?? "قناة"
        streamID = (try? container.decode(FlexString.self, forKey: .streamID))?.value ?? ""
        icon = (try? container.decode(String.self, forKey: .icon)) ?? ""
        epgChannelID = (try? container.decode(FlexString.self, forKey: .epgChannelID))?.value ?? ""
        categoryID = (try? container.decode(FlexString.self, forKey: .categoryID))?.value ?? ""
    }
}

private struct XtreamVOD: Decodable {
    var name: String
    var streamID: String
    var icon: String
    var categoryID: String
    var container: String
    var plot: String
    var year: String
    var genre: String
    var rating: String
    enum CodingKeys: String, CodingKey {
        case name
        case streamID = "stream_id"
        case icon = "stream_icon"
        case categoryID = "category_id"
        case container = "container_extension"
        case plot, year, genre, rating
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? container.decode(String.self, forKey: .name)) ?? "فيلم"
        streamID = (try? container.decode(FlexString.self, forKey: .streamID))?.value ?? ""
        icon = (try? container.decode(String.self, forKey: .icon)) ?? ""
        categoryID = (try? container.decode(FlexString.self, forKey: .categoryID))?.value ?? ""
        container = (try? container.decode(String.self, forKey: .container)) ?? "mp4"
        plot = (try? container.decode(String.self, forKey: .plot)) ?? ""
        year = (try? container.decode(FlexString.self, forKey: .year))?.value ?? ""
        genre = (try? container.decode(String.self, forKey: .genre)) ?? ""
        rating = (try? container.decode(FlexString.self, forKey: .rating))?.value ?? ""
    }
}

private struct XtreamSeries: Decodable {
    var seriesID: String
    var name: String
    var cover: String
    var plot: String
    var categoryID: String
    var genre: String
    var releaseDate: String
    var rating: String
    var backdrop: String
    enum CodingKeys: String, CodingKey {
        case seriesID = "series_id"
        case name, cover, plot, genre, rating
        case categoryID = "category_id"
        case releaseDate
        case backdropPath = "backdrop_path"
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        seriesID = (try? container.decode(FlexString.self, forKey: .seriesID))?.value ?? ""
        name = (try? container.decode(String.self, forKey: .name)) ?? "مسلسل"
        cover = (try? container.decode(String.self, forKey: .cover)) ?? ""
        plot = (try? container.decode(String.self, forKey: .plot)) ?? ""
        categoryID = (try? container.decode(FlexString.self, forKey: .categoryID))?.value ?? ""
        genre = (try? container.decode(String.self, forKey: .genre)) ?? ""
        releaseDate = (try? container.decode(String.self, forKey: .releaseDate)) ?? ""
        rating = (try? container.decode(FlexString.self, forKey: .rating))?.value ?? ""
        if let paths = try? container.decode([String].self, forKey: .backdropPath) {
            backdrop = paths.first ?? ""
        } else {
            backdrop = ""
        }
    }
}

private struct XtreamSeriesInfo: Decodable {
    var seasons: [String: [XtreamEpisode]]
    enum CodingKeys: String, CodingKey { case episodes }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let dict = try? container.decode([String: [XtreamEpisode]].self, forKey: .episodes) {
            seasons = dict
        } else {
            seasons = [:]
        }
    }
}

private struct XtreamEpisode: Decodable {
    var id: String
    var episodeNum: String
    var title: String
    var container: String
    var plot: String
    var duration: String
    var image: String
    enum CodingKeys: String, CodingKey {
        case id, title
        case episodeNum = "episode_num"
        case container = "container_extension"
        case info
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(FlexString.self, forKey: .id))?.value ?? ""
        episodeNum = (try? container.decode(FlexString.self, forKey: .episodeNum))?.value ?? ""
        title = (try? container.decode(String.self, forKey: .title)) ?? ""
        container = (try? container.decode(String.self, forKey: .container)) ?? "mp4"
        let info = try? container.decode(Info.self, forKey: .info)
        plot = info?.plot ?? ""
        duration = info?.duration ?? ""
        image = info?.image ?? ""
    }
    struct Info: Decodable {
        var plot: String
        var duration: String
        var image: String
        enum CodingKeys: String, CodingKey {
            case plot, duration
            case image = "movie_image"
        }
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            plot = (try? container.decode(String.self, forKey: .plot)) ?? ""
            duration = (try? container.decode(FlexString.self, forKey: .duration))?.value ?? ""
            image = (try? container.decode(String.self, forKey: .image)) ?? ""
        }
    }
}

private struct XtreamEPGResponse: Decodable {
    var epgListings: [Listing]
    enum CodingKeys: String, CodingKey { case epgListings = "epg_listings" }
    struct Listing: Decodable {
        var title: String
        var description: String
        var start: String
        var end: String
        var startTimestamp: String
        var stopTimestamp: String
        enum CodingKeys: String, CodingKey {
            case title, description, start, end
            case startTimestamp = "start_timestamp"
            case stopTimestamp = "stop_timestamp"
        }
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            title = (try? container.decode(String.self, forKey: .title)) ?? ""
            description = (try? container.decode(String.self, forKey: .description)) ?? ""
            start = (try? container.decode(String.self, forKey: .start)) ?? ""
            end = (try? container.decode(String.self, forKey: .end)) ?? ""
            startTimestamp = (try? container.decode(FlexString.self, forKey: .startTimestamp))?.value ?? ""
            stopTimestamp = (try? container.decode(FlexString.self, forKey: .stopTimestamp))?.value ?? ""
        }
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        epgListings = (try? container.decode([Listing].self, forKey: .epgListings)) ?? []
    }
}
