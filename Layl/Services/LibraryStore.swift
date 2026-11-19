import Foundation
import SwiftData

@MainActor
final class LibraryStore {
    let context: ModelContext

    init(container: ModelContainer) {
        context = ModelContext(container)
        context.autosaveEnabled = true
        seedProfilesIfNeeded()
    }

    func save() {
        try? context.save()
    }

    func seedProfilesIfNeeded() {
        let existing = profiles()
        guard existing.isEmpty else { return }
        let rows = [
            ProfileRecord(id: UUID(), name: "ليل", avatarAsset: "AvatarLayl", symbol: "", isKids: false, sortIndex: 0),
            ProfileRecord(id: UUID(), name: "العائلة", avatarAsset: "", symbol: "person.2.fill", isKids: false, sortIndex: 1),
            ProfileRecord(id: UUID(), name: "أطفال", avatarAsset: "PosterRabbit", symbol: "", isKids: true, sortIndex: 2)
        ]
        rows.forEach { context.insert($0) }
        save()
    }

    func profiles() -> [Profile] {
        let rows = (try? context.fetch(FetchDescriptor<ProfileRecord>())) ?? []
        return rows.sorted { $0.sortIndex < $1.sortIndex }.map { $0.asProfile() }
    }

    func playlists() -> [Playlist] {
        let rows = (try? context.fetch(FetchDescriptor<PlaylistRecord>())) ?? []
        return rows.sorted { $0.createdAt < $1.createdAt }.map { $0.asPlaylist() }
    }

    func upsertPlaylist(name: String, kind: PlaylistKind, url: String, username: String, password: String, epgURL: String) -> Playlist {
        let id = UUID()
        let record = PlaylistRecord(
            id: id,
            name: name,
            kindRaw: kind.rawValue,
            url: url,
            username: username,
            secretFallback: "",
            epgURL: epgURL,
            createdAt: .now
        )
        if !password.isEmpty {
            KeychainStore.set(password, account: id.uuidString)
            record.secretFallback = password
        }
        context.insert(record)
        save()
        return record.asPlaylist()
    }

    func password(for playlist: Playlist) -> String {
        if let secret = KeychainStore.get(account: playlist.id.uuidString), !secret.isEmpty {
            return secret
        }
        return record(playlist.id)?.secretFallback ?? ""
    }

    func markSynced(_ id: UUID, epgURL: String?) {
        guard let record = record(id) else { return }
        record.lastSyncedAt = .now
        if let epgURL, !epgURL.isEmpty, record.epgURL.isEmpty {
            record.epgURL = epgURL
        }
        save()
    }

    func deletePlaylist(_ id: UUID) {
        guard let record = record(id) else { return }
        KeychainStore.remove(account: id.uuidString)
        context.delete(record)
        save()
    }

    func isFavorite(profile: UUID, mediaID: String) -> Bool {
        favorites(profile: profile).contains { $0.mediaID == mediaID }
    }

    func favorites(profile: UUID) -> [FavoriteRecord] {
        let rows = (try? context.fetch(FetchDescriptor<FavoriteRecord>())) ?? []
        return rows.filter { $0.profileID == profile }.sorted { $0.addedAt > $1.addedAt }
    }

    @discardableResult
    func toggleFavorite(profile: UUID, item: MediaItem) -> Bool {
        let key = "\(profile.uuidString)|\(item.id)"
        if let existing = favorites(profile: profile).first(where: { $0.mediaID == item.id }) {
            context.delete(existing)
            save()
            return false
        }
        context.insert(
            FavoriteRecord(
                key: key,
                profileID: profile,
                mediaID: item.id,
                title: item.title,
                kindRaw: item.kind.rawValue,
                posterAsset: item.posterAsset ?? "",
                posterURL: item.posterURL ?? "",
                addedAt: .now
            )
        )
        save()
        return true
    }

    func progressEntries(profile: UUID) -> [ContinueEntry] {
        let rows = (try? context.fetch(FetchDescriptor<WatchProgressRecord>())) ?? []
        return rows
            .filter { $0.profileID == profile && $0.duration > 0 && $0.position / $0.duration < 0.95 && $0.position > 4 }
            .sorted { $0.updatedAt > $1.updatedAt }
            .map { $0.asEntry() }
    }

    func progress(profile: UUID, mediaID: String) -> WatchProgressRecord? {
        let rows = (try? context.fetch(FetchDescriptor<WatchProgressRecord>())) ?? []
        return rows.first { $0.profileID == profile && $0.mediaID == mediaID }
    }

    func saveProgress(
        profile: UUID,
        mediaID: String,
        title: String,
        subtitle: String,
        posterAsset: String,
        posterURL: String,
        kind: MediaKind,
        streamURL: String,
        position: Double,
        duration: Double,
        seriesID: String,
        seasonNumber: Int,
        episodeNumber: Int
    ) {
        if let existing = progress(profile: profile, mediaID: mediaID) {
            existing.position = position
            existing.duration = duration
            existing.updatedAt = .now
            existing.subtitle = subtitle
        } else {
            context.insert(
                WatchProgressRecord(
                    key: "\(profile.uuidString)|\(mediaID)",
                    profileID: profile,
                    mediaID: mediaID,
                    title: title,
                    subtitle: subtitle,
                    posterAsset: posterAsset,
                    posterURL: posterURL,
                    kindRaw: kind.rawValue,
                    streamURL: streamURL,
                    position: position,
                    duration: duration,
                    updatedAt: .now,
                    seriesID: seriesID,
                    seasonNumber: seasonNumber,
                    episodeNumber: episodeNumber
                )
            )
        }
        save()
    }

    func clearProgress(profile: UUID) {
        let rows = (try? context.fetch(FetchDescriptor<WatchProgressRecord>())) ?? []
        rows.filter { $0.profileID == profile }.forEach { context.delete($0) }
        save()
    }

    func reaction(profile: UUID, mediaID: String) -> Reaction? {
        let rows = (try? context.fetch(FetchDescriptor<ReactionRecord>())) ?? []
        guard let raw = rows.first(where: { $0.profileID == profile && $0.mediaID == mediaID })?.reactionRaw else { return nil }
        return Reaction(rawValue: raw)
    }

    func setReaction(profile: UUID, mediaID: String, reaction: Reaction?) {
        let rows = (try? context.fetch(FetchDescriptor<ReactionRecord>())) ?? []
        if let existing = rows.first(where: { $0.profileID == profile && $0.mediaID == mediaID }) {
            if let reaction {
                existing.reactionRaw = reaction.rawValue
            } else {
                context.delete(existing)
            }
        } else if let reaction {
            context.insert(
                ReactionRecord(
                    key: "\(profile.uuidString)|\(mediaID)",
                    profileID: profile,
                    mediaID: mediaID,
                    reactionRaw: reaction.rawValue
                )
            )
        }
        save()
    }

    func downloads() -> [DownloadItem] {
        let rows = (try? context.fetch(FetchDescriptor<DownloadRecord>())) ?? []
        return rows.sorted { $0.createdAt > $1.createdAt }.map { $0.asItem() }
    }

    func upsertDownload(_ item: DownloadItem) {
        let rows = (try? context.fetch(FetchDescriptor<DownloadRecord>())) ?? []
        if let existing = rows.first(where: { $0.mediaID == item.mediaID }) {
            existing.title = item.title
            existing.posterAsset = item.posterAsset
            existing.posterURL = item.posterURL
            existing.remoteURL = item.remoteURL
            existing.localPath = item.localPath
            existing.bookmarkData = item.bookmarkData
            existing.stateRaw = item.state.rawValue
            existing.progress = item.progress
            existing.errorMessage = item.errorMessage
            existing.isHLS = item.isHLS
        } else {
            context.insert(
                DownloadRecord(
                    mediaID: item.mediaID,
                    title: item.title,
                    posterAsset: item.posterAsset,
                    posterURL: item.posterURL,
                    remoteURL: item.remoteURL,
                    localPath: item.localPath,
                    bookmarkData: item.bookmarkData,
                    stateRaw: item.state.rawValue,
                    progress: item.progress,
                    errorMessage: item.errorMessage,
                    isHLS: item.isHLS,
                    createdAt: .now
                )
            )
        }
        save()
    }

    func deleteDownload(_ mediaID: String) {
        let rows = (try? context.fetch(FetchDescriptor<DownloadRecord>())) ?? []
        rows.filter { $0.mediaID == mediaID }.forEach { context.delete($0) }
        save()
    }

    private func record(_ id: UUID) -> PlaylistRecord? {
        let rows = (try? context.fetch(FetchDescriptor<PlaylistRecord>())) ?? []
        return rows.first { $0.id == id }
    }
}
