import Foundation
import SwiftData

enum LaylSchema {
    static let schema = Schema([
        PlaylistRecord.self,
        FavoriteRecord.self,
        WatchProgressRecord.self,
        DownloadRecord.self,
        ReactionRecord.self,
        ProfileRecord.self
    ])
}

@Model
final class PlaylistRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var kindRaw: String
    var url: String
    var username: String
    var secretFallback: String
    var epgURL: String
    var createdAt: Date
    var lastSyncedAt: Date?

    init(
        id: UUID,
        name: String,
        kindRaw: String,
        url: String,
        username: String,
        secretFallback: String,
        epgURL: String,
        createdAt: Date,
        lastSyncedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.kindRaw = kindRaw
        self.url = url
        self.username = username
        self.secretFallback = secretFallback
        self.epgURL = epgURL
        self.createdAt = createdAt
        self.lastSyncedAt = lastSyncedAt
    }

    func asPlaylist() -> Playlist {
        Playlist(
            id: id,
            name: name,
            kind: PlaylistKind(rawValue: kindRaw) ?? .m3u,
            url: url,
            username: username,
            epgURL: epgURL,
            createdAt: createdAt,
            lastSyncedAt: lastSyncedAt
        )
    }
}

@Model
final class FavoriteRecord {
    @Attribute(.unique) var key: String
    var profileID: UUID
    var mediaID: String
    var title: String
    var kindRaw: String
    var posterAsset: String
    var posterURL: String
    var addedAt: Date

    init(key: String, profileID: UUID, mediaID: String, title: String, kindRaw: String, posterAsset: String, posterURL: String, addedAt: Date) {
        self.key = key
        self.profileID = profileID
        self.mediaID = mediaID
        self.title = title
        self.kindRaw = kindRaw
        self.posterAsset = posterAsset
        self.posterURL = posterURL
        self.addedAt = addedAt
    }
}

@Model
final class WatchProgressRecord {
    @Attribute(.unique) var key: String
    var profileID: UUID
    var mediaID: String
    var title: String
    var subtitle: String
    var posterAsset: String
    var posterURL: String
    var kindRaw: String
    var streamURL: String
    var position: Double
    var duration: Double
    var updatedAt: Date
    var seriesID: String
    var seasonNumber: Int
    var episodeNumber: Int

    init(
        key: String,
        profileID: UUID,
        mediaID: String,
        title: String,
        subtitle: String,
        posterAsset: String,
        posterURL: String,
        kindRaw: String,
        streamURL: String,
        position: Double,
        duration: Double,
        updatedAt: Date,
        seriesID: String,
        seasonNumber: Int,
        episodeNumber: Int
    ) {
        self.key = key
        self.profileID = profileID
        self.mediaID = mediaID
        self.title = title
        self.subtitle = subtitle
        self.posterAsset = posterAsset
        self.posterURL = posterURL
        self.kindRaw = kindRaw
        self.streamURL = streamURL
        self.position = position
        self.duration = duration
        self.updatedAt = updatedAt
        self.seriesID = seriesID
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
    }

    func asEntry() -> ContinueEntry {
        ContinueEntry(
            mediaID: mediaID,
            title: title,
            subtitle: subtitle,
            posterAsset: posterAsset,
            posterURL: posterURL,
            position: position,
            duration: duration,
            streamURL: streamURL,
            kind: MediaKind(rawValue: kindRaw) ?? .movie,
            seriesID: seriesID,
            seasonNumber: seasonNumber,
            episodeNumber: episodeNumber
        )
    }
}

@Model
final class DownloadRecord {
    @Attribute(.unique) var mediaID: String
    var title: String
    var posterAsset: String
    var posterURL: String
    var remoteURL: String
    var localPath: String
    var bookmarkData: Data?
    var stateRaw: String
    var progress: Double
    var errorMessage: String
    var isHLS: Bool
    var createdAt: Date

    init(
        mediaID: String,
        title: String,
        posterAsset: String,
        posterURL: String,
        remoteURL: String,
        localPath: String,
        bookmarkData: Data? = nil,
        stateRaw: String,
        progress: Double,
        errorMessage: String,
        isHLS: Bool,
        createdAt: Date
    ) {
        self.mediaID = mediaID
        self.title = title
        self.posterAsset = posterAsset
        self.posterURL = posterURL
        self.remoteURL = remoteURL
        self.localPath = localPath
        self.bookmarkData = bookmarkData
        self.stateRaw = stateRaw
        self.progress = progress
        self.errorMessage = errorMessage
        self.isHLS = isHLS
        self.createdAt = createdAt
    }

    func asItem() -> DownloadItem {
        DownloadItem(
            mediaID: mediaID,
            title: title,
            posterAsset: posterAsset,
            posterURL: posterURL,
            remoteURL: remoteURL,
            localPath: localPath,
            bookmarkData: bookmarkData,
            state: DownloadState(rawValue: stateRaw) ?? .failed,
            progress: progress,
            errorMessage: errorMessage,
            isHLS: isHLS
        )
    }
}

@Model
final class ReactionRecord {
    @Attribute(.unique) var key: String
    var profileID: UUID
    var mediaID: String
    var reactionRaw: String

    init(key: String, profileID: UUID, mediaID: String, reactionRaw: String) {
        self.key = key
        self.profileID = profileID
        self.mediaID = mediaID
        self.reactionRaw = reactionRaw
    }
}

@Model
final class ProfileRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var avatarAsset: String
    var symbol: String
    var isKids: Bool
    var sortIndex: Int

    init(id: UUID, name: String, avatarAsset: String, symbol: String, isKids: Bool, sortIndex: Int) {
        self.id = id
        self.name = name
        self.avatarAsset = avatarAsset
        self.symbol = symbol
        self.isKids = isKids
        self.sortIndex = sortIndex
    }

    func asProfile() -> Profile {
        Profile(
            id: id,
            name: name,
            avatarAsset: avatarAsset,
            symbol: symbol.isEmpty ? nil : symbol,
            isKids: isKids
        )
    }
}
