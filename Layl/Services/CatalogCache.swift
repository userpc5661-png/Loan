import Foundation

struct CatalogCache {
    let folder: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Layl", isDirectory: true)
        folder = base.appendingPathComponent("catalogs", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    func save(_ catalog: Catalog, playlistID: UUID) {
        let url = folder.appendingPathComponent("\(playlistID.uuidString).json")
        guard let data = try? JSONEncoder().encode(catalog) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func load(playlistID: UUID) -> Catalog? {
        let url = folder.appendingPathComponent("\(playlistID.uuidString).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Catalog.self, from: data)
    }

    func remove(playlistID: UUID) {
        let url = folder.appendingPathComponent("\(playlistID.uuidString).json")
        try? FileManager.default.removeItem(at: url)
    }

    func importFolder() -> URL {
        let url = folder.deletingLastPathComponent().appendingPathComponent("imports", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
