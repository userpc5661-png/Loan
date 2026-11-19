import Foundation

struct M3UEntry: Hashable, Sendable {
    var name: String
    var group: String
    var logo: String
    var url: String
    var tvgID: String
    var kind: M3UKind
}

enum M3UKind: String, Sendable {
    case live, movie, episode
}

enum M3UParser {
    struct Result: Sendable {
        var catalog: Catalog
        var epgURL: String?
    }

    static func parse(_ text: String, playlistID: UUID) -> Result {
        let lines = text.split(whereSeparator: \.isNewline).map { String($0).trimmingCharacters(in: .whitespaces) }
        var epgURL: String?
        var pending: [String: String] = [:]
        var pendingName: String?
        var entries: [M3UEntry] = []

        for line in lines {
            if line.isEmpty || line.hasPrefix("##") { continue }
            if line.hasPrefix("#EXTM3U") {
                let attributes = attributes(in: line)
                epgURL = attributes["url-tvg"] ?? attributes["x-tvg-url"] ?? epgURL
                continue
            }
            if line.hasPrefix("#EXTINF") {
                let attributes = attributes(in: line)
                pending = attributes
                pendingName = displayName(from: line)
                continue
            }
            if line.hasPrefix("#") { continue }
            guard line.contains("://") || line.hasPrefix("/") else { continue }
            let name = pendingName?.isEmpty == false ? pendingName! : (pending["tvg-name"] ?? "قناة")
            let group = pending["group-title"] ?? ""
            let entry = M3UEntry(
                name: name,
                group: group,
                logo: pending["tvg-logo"] ?? "",
                url: line,
                tvgID: pending["tvg-id"] ?? "",
                kind: classify(name: name, group: group, url: line)
            )
            entries.append(entry)
            pending = [:]
            pendingName = nil
        }

        return Result(catalog: buildCatalog(entries, playlistID: playlistID), epgURL: epgURL)
    }

    static func attributes(in line: String) -> [String: String] {
        var result: [String: String] = [:]
        let pattern = #"([A-Za-z0-9\-]+)\s*=\s*"([^"]*)"|([A-Za-z0-9\-]+)\s*=\s*([^\s",]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return result }
        let range = NSRange(line.startIndex..., in: line)
        for match in regex.matches(in: line, range: range) {
            if let keyRange = Range(match.range(at: 1), in: line),
               let valueRange = Range(match.range(at: 2), in: line) {
                result[String(line[keyRange])] = String(line[valueRange])
            } else if let keyRange = Range(match.range(at: 3), in: line),
                      let valueRange = Range(match.range(at: 4), in: line) {
                result[String(line[keyRange])] = String(line[valueRange])
            }
        }
        return result
    }

    static func displayName(from extinf: String) -> String {
        var quote = false
        var commaIndex: String.Index?
        for index in extinf.indices {
            let character = extinf[index]
            if character == "\"" { quote.toggle() }
            if character == "," && !quote {
                commaIndex = index
                break
            }
        }
        guard let commaIndex else { return "" }
        return extinf[extinf.index(after: commaIndex)...].trimmingCharacters(in: .whitespaces)
    }

    static func classify(name: String, group: String, url: String) -> M3UKind {
        let loweredGroup = group.lowercased()
        let loweredURL = url.lowercased()
        if episodeMatch(in: name) != nil || loweredURL.contains("/series/") {
            return .episode
        }
        if loweredGroup.contains("series") || group.contains("مسلسل") {
            return .episode
        }
        let videoExtensions = [".mp4", ".mkv", ".avi", ".mov", ".m4v", ".ts"]
        if loweredURL.contains("/movie/") || videoExtensions.contains(where: { loweredURL.contains($0) }) {
            return .movie
        }
        if !loweredURL.contains(".m3u8"),
           loweredGroup.contains("movie") || loweredGroup.contains("vod") || group.contains("أفلام") || group.contains("فيلم") {
            return .movie
        }
        return .live
    }

    struct EpisodeMatch {
        var show: String
        var season: Int
        var episode: Int
    }

    static func episodeMatch(in name: String) -> EpisodeMatch? {
        let pattern = #"(?i)^(.+?)[\s\-_\.]+S(\d{1,2})[\s\-_\.]*E(\d{1,3})"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
              let showRange = Range(match.range(at: 1), in: name),
              let seasonRange = Range(match.range(at: 2), in: name),
              let episodeRange = Range(match.range(at: 3), in: name),
              let season = Int(name[seasonRange]),
              let episode = Int(name[episodeRange]) else {
            if let arabic = arabicEpisode(in: name) { return arabic }
            return nil
        }
        return EpisodeMatch(show: String(name[showRange]).trimmingCharacters(in: .whitespaces), season: season, episode: episode)
    }

    private static func arabicEpisode(in name: String) -> EpisodeMatch? {
        let pattern = #"^(.+?)\s+الحلقة\s*(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
              let showRange = Range(match.range(at: 1), in: name),
              let episodeRange = Range(match.range(at: 2), in: name),
              let episode = Int(name[episodeRange]) else { return nil }
        return EpisodeMatch(show: String(name[showRange]), season: 1, episode: episode)
    }

    static func buildCatalog(_ entries: [M3UEntry], playlistID: UUID) -> Catalog {
        let prefix = playlistID.uuidString
        var movies: [MediaItem] = []
        var channels: [LiveChannel] = []
        var seriesBuckets: [String: (title: String, group: String, logo: String, episodes: [Episode])] = [:]

        for (index, entry) in entries.enumerated() {
            switch entry.kind {
            case .movie:
                movies.append(
                    MediaItem(
                        id: "pl.\(prefix).movie.\(index)",
                        kind: .movie,
                        title: entry.name,
                        overview: entry.group,
                        year: nil,
                        rating: nil,
                        quality: "HD",
                        genres: entry.group.isEmpty ? [] : [entry.group],
                        posterAsset: nil,
                        posterURL: entry.logo.isEmpty ? nil : entry.logo,
                        backdropAsset: nil,
                        backdropURL: nil,
                        streamURL: entry.url,
                        durationMinutes: nil,
                        category: entry.group.isEmpty ? "أفلام" : entry.group,
                        playlistID: prefix,
                        isDemo: false,
                        credit: nil
                    )
                )
            case .live:
                channels.append(
                    LiveChannel(
                        id: "pl.\(prefix).live.\(index)",
                        name: entry.name,
                        number: channels.count + 1,
                        category: entry.group.isEmpty ? "عام" : entry.group,
                        logoAsset: nil,
                        logoURL: entry.logo.isEmpty ? nil : entry.logo,
                        streamURL: entry.url,
                        epgID: entry.tvgID.isEmpty ? entry.name : entry.tvgID,
                        programs: [],
                        playlistID: prefix,
                        isDemo: false
                    )
                )
            case .episode:
                let match = episodeMatch(in: entry.name)
                let show = match?.show ?? (entry.group.isEmpty ? entry.name : entry.group)
                let seasonNumber = match?.season ?? 1
                let episodeNumber = match?.episode ?? ((seriesBuckets[show]?.episodes.count ?? 0) + 1)
                let episode = Episode(
                    id: "pl.\(prefix).ep.\(index)",
                    number: episodeNumber,
                    seasonNumber: seasonNumber,
                    title: match == nil ? entry.name : "الحلقة \(episodeNumber)",
                    overview: "",
                    durationMinutes: 0,
                    stillAsset: nil,
                    stillURL: entry.logo.isEmpty ? nil : entry.logo,
                    streamURL: entry.url
                )
                if seriesBuckets[show] == nil {
                    seriesBuckets[show] = (show, entry.group, entry.logo, [episode])
                } else {
                    seriesBuckets[show]?.episodes.append(episode)
                }
            }
        }

        let series: [SeriesDetail] = seriesBuckets.keys.sorted().map { key in
            let bucket = seriesBuckets[key]!
            let grouped = Dictionary(grouping: bucket.episodes, by: \.seasonNumber)
            let seasons = grouped.keys.sorted().map { number in
                Season(
                    id: "pl.\(prefix).season.\(key).\(number)",
                    number: number,
                    title: "\(Copy.season) \(number)",
                    episodes: grouped[number]!.sorted { $0.number < $1.number }
                )
            }
            let item = MediaItem(
                id: "pl.\(prefix).series.\(key)",
                kind: .series,
                title: bucket.title,
                overview: bucket.group,
                year: nil,
                rating: nil,
                quality: "HD",
                genres: bucket.group.isEmpty ? [] : [bucket.group],
                posterAsset: nil,
                posterURL: bucket.logo.isEmpty ? nil : bucket.logo,
                backdropAsset: nil,
                backdropURL: nil,
                streamURL: seasons.first?.episodes.first?.streamURL,
                durationMinutes: nil,
                category: bucket.group.isEmpty ? "مسلسلات" : bucket.group,
                playlistID: prefix,
                isDemo: false,
                credit: nil
            )
            return SeriesDetail(id: item.id, item: item, seasons: seasons)
        }

        return Catalog(movies: movies, series: series, channels: channels, clips: [])
    }
}
